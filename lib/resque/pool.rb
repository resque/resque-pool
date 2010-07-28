# -*- encoding: utf-8 -*-
require 'resque'
require 'fcntl'
require 'yaml'

module Resque
  class Pool
    attr_reader :pool_config
    attr_reader :workers

    SELF_PIPE = []
    SIG_QUEUE = []
    QUEUE_SIGS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, ]
    CHUNK_SIZE=(16 * 1024)

    def initialize(config)
      if config.respond_to? :keys
        @pool_config = config.dup
      else
        @pool_config_file = config.to_s
        log "**** loading config from #{@pool_config_file}"
        @pool_config = YAML.load_file(@pool_config_file)
      end
      log "**** config: #{@pool_config.inspect}"
      @workers = pool_config.keys.inject({}) {|h,k| h[k] = {}; h}
      procline "(initialized)"
    end


    # The `after_prefork` hook will be run in workers if you are using the
    # preforking master worker to save memory. Use this hook to reload
    # database connections and so forth to ensure that they're not shared
    # among workers.
    #
    # Call with a block to set the hook.
    # Call with no arguments to return the hook.
    def self.after_prefork(&block)
      block ? (@after_prefork = block) : @after_prefork
    end

    # Set the after_prefork proc.
    def self.after_prefork=(after_prefork)
      @after_prefork = after_prefork
    end

    def call_after_prefork!
      self.class.after_prefork && self.class.after_prefork.call
    end

    # Given a string, sets the procline ($0)
    # Procline is always in the format of:
    #   resque-pool-master: STRING
    def procline(string)
      $0 = "resque-pool-master: #{string}"
    end

    # TODO: make this use an actual logger
    def log(message)
      puts message
    end

    def init_self_pipe!
      SELF_PIPE.each { |io| io.close rescue nil }
      SELF_PIPE.replace(IO.pipe)
      SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def init_sig_handlers!
      QUEUE_SIGS.each { |sig| trap_deferred(sig) }
      trap(:CHLD)     { |_| awaken_master }
    end

    # defer a signal for later processing in #join (master process)
    def trap_deferred(signal)
      trap(signal) do |sig_nr|
        if SIG_QUEUE.size < 5
          SIG_QUEUE << signal
          awaken_master
        else
          log "ignoring SIG#{signal}, queue=#{SIG_QUEUE.inspect}"
        end
      end
    end

    def start
      procline("(starting)")
      init_self_pipe!
      init_sig_handlers!
      maintain_worker_count
      procline("(started)")
      log "**** done in pool master #initialize"
      log "**** Pool contains PIDs: #{all_pids.inspect}"
      self
    end

    def join
      loop do
        reap_all_workers
        break if handle_sig_queue! == :break
        maintain_worker_count if SIG_QUEUE.empty?
        procline("managing #{all_pids.inspect}")
      end
      procline("(shutting down)")
      #stop # gracefully shutdown all workers on our way out
      log "**** master complete"
      #unlink_pid_safe(pid) if pid
    end

    def handle_sig_queue!
      case SIG_QUEUE.shift
      when nil
        master_sleep
      when :QUIT # graceful shutdown
        :break
      when :TERM, :INT # immediate shutdown
        #stop(false)
        :break
      when :HUP
        log "**** reloading config"
        @pool_config = YAML.load_file(@pool_config_file)
        maintain_worker_count
      end
    end

    def reap_all_workers
      begin
        loop do
          wpid, status = Process.waitpid2(-1, Process::WNOHANG)
          wpid or break
          #if reexec_pid == wpid
            #log "reaped #{status.inspect} exec()-ed"
            #self.reexec_pid = 0
            #self.pid = pid.chomp('.oldbin') if pid
            #proc_name 'master'
          #else
            worker = delete_worker(wpid) #and worker.tmp.close rescue nil
            log "**** reaped #{status.inspect} " +
                        "worker=#{worker.nr rescue 'unknown'}"
          #end
        end
      rescue Errno::ECHILD
      end
    end

    def delete_worker(pid)
      workers.each do |queues, pid_to_worker|
        pid_to_worker.delete(pid)
      end
    end

    def master_sleep
      begin
        ready = IO.select([SELF_PIPE.first], nil, nil, 1) or return
        ready.first && ready.first.first or return
        loop { SELF_PIPE.first.read_nonblock(CHUNK_SIZE) }
      rescue Errno::EAGAIN, Errno::EINTR
      end
    end

    def awaken_master
      begin
        SELF_PIPE.last.write_nonblock('.') # wakeup master process from select
      rescue Errno::EAGAIN, Errno::EINTR
        # pipe is full, master should wake up anyways
        retry
      end
    end

    def maintain_worker_count
      pool_config.each do |queues, count|
        if worker_delta_for(queues) > 0
          spawn_missing_workers_for(queues)
        end
      end
      workers.each do |queues, workers|
        if worker_delta_for(queues) < 0
          quit_excess_workers_for(queues)
        end
      end
    end

    def all_pids
      workers.map {|q,workers| workers.keys }.flatten
    end

    ##
    # all methods below operate on a single grouping of queues
    # perhaps this means a class is waiting to be extracted

    def spawn_missing_workers_for(queues)
      worker_delta_for(queues).times do |nr|
        spawn_worker!(queues)
      end
    end

    def quit_excess_workers_for(queues)
      workers[queues].each do |pid, worker|
        Process.kill("HUP", pid)
      end
    end

    def worker_delta_for(queues)
      pool_config.fetch(queues, 0) - workers.fetch(queues, []).size
    end

    def spawn_worker!(queues)
      worker = create_worker(queues)
      pid = fork do
        log "*** Starting worker #{worker}"
        call_after_prefork!
        QUEUE_SIGS.each {|sig| trap(sig, "DEFAULT") }
        #SELF_PIPE.each {|io| io.close }
        worker.work(ENV['INTERVAL'] || 5) # interval, will block
      end
      workers[queues] ||= {}
      workers[queues][pid] = worker
    end

    def create_worker(queues)
      queues = queues.to_s.split(',')
      worker = Resque::Worker.new(*queues)
      worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
      worker.very_verbose = ENV['VVERBOSE']
      worker
    rescue Resque::NoQueueError
      abort "set QUEUE env var, e.g. $ QUEUE=critical,high rake resque:work"
    end

  end
end
