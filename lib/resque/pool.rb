# -*- encoding: utf-8 -*-
require 'resque'
require 'resque/pool/version'
require 'resque/pool/logging'
require 'resque/pool/pooled_worker'
require 'fcntl'
require 'yaml'

module Resque
  class Pool
    include Logging
    attr_reader :config
    attr_reader :workers

    # CONSTANTS {{{
    SIG_QUEUE_MAX_SIZE = 5
    DEFAULT_WORKER_INTERVAL = 5
    QUEUE_SIGS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :CONT, :HUP, :WINCH, ]
    CHUNK_SIZE=(16 * 1024)
    # }}}

    def initialize(config)
      init_config(config)
      @workers = {}
      procline "(initialized)"
    end

    # Config: after_prefork {{{

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

    # }}}
    # Config: class methods to start up the pool using the default config {{{

    @config_files = ["resque-pool.yml", "config/resque-pool.yml"]
    class << self; attr_accessor :config_files; end
    def self.choose_config_file
      if ENV["RESQUE_POOL_CONFIG"]
        ENV["RESQUE_POOL_CONFIG"]
      else
        @config_files.detect { |f| File.exist?(f) }
      end
    end

    def self.run
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
      Resque::Pool.new(choose_config_file).start.join
    end

    # }}}
    # Config: load config and config file {{{

    def init_config(config)
      unless config
        raise ArgumentError,
          "No configuration found. Please setup config/resque-pool.yml"
      end
      if config.kind_of? String
        @config_file = config.to_s
      else
        @config = config.dup
      end
      load_config
    end

    def load_config
      @config_file and @config = YAML.load_file(@config_file)
      environment and @config[environment] and config.merge!(@config[environment])
      config.delete_if {|key, value| value.is_a? Hash }
    end

    def environment
      if defined? Rails
        Rails.env
      else
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || ENV['RESQUE_ENV']
      end
    end

    # }}}

    # Sig handlers and self pipe management {{{

    def self_pipe; @self_pipe ||= [] end
    def sig_queue; @sig_queue ||= [] end

    def init_self_pipe!
      self_pipe.each { |io| io.close rescue nil }
      self_pipe.replace(IO.pipe)
      self_pipe.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def init_sig_handlers!
      QUEUE_SIGS.each { |sig| trap_deferred(sig) }
      trap(:CHLD)     { |_| awaken_master }
    end

    def awaken_master
      begin
        self_pipe.last.write_nonblock('.') # wakeup master process from select
      rescue Errno::EAGAIN, Errno::EINTR
        # pipe is full, master should wake up anyways
        retry
      end
    end

    # defer a signal for later processing in #join (master process)
    def trap_deferred(signal)
      trap(signal) do |sig_nr|
        if sig_queue.size < SIG_QUEUE_MAX_SIZE
          sig_queue << signal
          awaken_master
        else
          log "ignoring SIG#{signal}, queue=#{sig_queue.inspect}"
        end
      end
    end

    def reset_sig_handlers!
      QUEUE_SIGS.each {|sig| trap(sig, "DEFAULT") }
    end

    def handle_sig_queue!
      case signal = sig_queue.shift
      when :USR1, :USR2, :CONT
        log "#{signal}: sending to all workers"
        signal_all_workers(signal)
      when :HUP
        log "HUP: reload config file"
        load_config
        maintain_worker_count
      when :WINCH
        log "WINCH: gracefully stopping all workers"
        @config = {}
        maintain_worker_count
      when :QUIT
        log "QUIT: graceful shutdown, waiting for children"
        signal_all_workers(:QUIT)
        reap_all_workers(0) # will hang until all workers are shutdown
        :break
      when :INT
        log "INT: immediate shutdown (graceful worker shutdown)"
        signal_all_workers(:QUIT)
        :break
      when :TERM
        log "TERM: immediate shutdown (and immediate worker shutdown)"
        signal_all_workers(:TERM)
        :break
      end
    end

    # }}}
    # start, join, and master sleep {{{

    def start
      procline("(starting)")
      init_self_pipe!
      init_sig_handlers!
      maintain_worker_count
      procline("(started)")
      log "**** started master at PID: #{Process.pid}"
      log "**** Pool contains PIDs: #{all_pids.inspect}"
      self
    end

    def join
      loop do
        reap_all_workers
        break if handle_sig_queue! == :break
        if sig_queue.empty?
          master_sleep
          monitor_memory_usage
          maintain_worker_count
        end
        procline("managing #{all_pids.inspect}")
      end
      procline("(shutting down)")
      #stop # gracefully shutdown all workers on our way out
      log "**** master complete"
      #unlink_pid_safe(pid) if pid
    end

    def master_sleep
      begin
        ready = IO.select([self_pipe.first], nil, nil, 1) or return
        ready.first && ready.first.first or return
        loop { self_pipe.first.read_nonblock(CHUNK_SIZE) }
      rescue Errno::EAGAIN, Errno::EINTR
      end
    end

    # }}}
    # worker process management {{{

    def reap_all_workers(waitpid_flags=Process::WNOHANG)
      begin
        loop do
          wpid, status = Process.waitpid2(-1, waitpid_flags)
          wpid or break
          worker = delete_worker(wpid)
          # TODO: close any file descriptors connected to worker, if any
          log "** reaped #{status.inspect}, worker=#{worker.queues.join(",")}"
        end
      rescue Errno::ECHILD
      end
    end

    def delete_worker(pid)
      worker = nil
      workers.detect do |queues, pid_to_worker|
        worker = pid_to_worker.delete(pid)
      end
      worker
    end

    def all_pids
      workers.map {|q,workers| workers.keys }.flatten
    end

    def signal_all_workers(signal)
      all_pids.each do |pid|
        Process.kill signal, pid
      end
    end

    def monitor_memory_usage
      #only check every minute
      if @last_mem_check.nil? || @last_mem_check < Time.now - 60
        
        all_pids.each do |pid|
          smaps_filename = "/proc/#{pid}/smaps"
          
          #Grab actual memory usage from proc in MB
          begin
            mem_usage = `
              if [ -f #{smaps_filename} ];
                then
                  grep Private_Dirty #{smaps_filename} | awk '{s+=$2} END {printf("%d", s/1000)}'
                else echo "0"
              fi
            `.to_i
          rescue Errno::EINTR
            retry
          end

          if mem_usage > 800
            log "Terminating worker #{pid} for using #{mem_usage}MB memory"
            Process.kill :TERM, pid
          elsif mem_usage > 400
            log "Gracefully shutting down worker #{pid} for using #{mem_usage}MB memory"
            Process.kill :QUIT, pid
          end

        end

        @last_mem_check = Time.now
      end
    end

    def orphaned_worker_count
      if @last_orphaned_check.nil? || @last_orphaned_check < Time.now - 60
        if @orphaned_pids.nil?
            printf_line = '%d %d\n'
          pids_with_parents = `ps -f axf | grep resque | grep -v grep | grep -v resque-web | grep -v master | awk '{printf("%d %d\\n", $2, $3)}'`.split("\n")
          pids = pids_with_parents.collect {|x| x.split[0].to_i}
          parents = pids_with_parents.collect {|x| x.split[1].to_i}
          pids.delete_if {|x| parents.include?(x)}
          pids.delete_if {|x| all_pids.include?(x)}
          @orphaned_pids = pids
        elsif @orphaned_pids.size > 0
          @orphaned_pids.delete_if do |pid|
            ps_out = `ps --no-heading p #{pid}`
            ps_out.nil? || ps_out.strip == ''
          end
        end
        @last_orphaned_check = Time.now
        log "Current orphaned pids: #{@orphaned_pids}" if @orphaned_pids.size > 0
      end
      @orphaned_pids.size
    end

    # }}}
    # ???: maintain_worker_count, all_known_queues {{{

    def maintain_worker_count
      orphaned_offset = orphaned_worker_count / all_known_queues.size
      all_known_queues.each do |queues|
        delta = worker_delta_for(queues) - orphaned_offset
        spawn_missing_workers_for(queues, delta) if delta > 0
        quit_excess_workers_for(queues, delta)   if delta < 0
      end
    end

    def all_known_queues
      config.keys | workers.keys
    end

    # }}}
    # methods that operate on a single grouping of queues {{{
    # perhaps this means a class is waiting to be extracted

    def spawn_missing_workers_for(queues, delta)
      delta.times { spawn_worker!(queues) } if delta > 0
    end

    def quit_excess_workers_for(queues, delta)
      if delta < 0
        queue_pids = pids_for(queues)
        if queue_pids.size >= delta.abs
          queue_pids[0...delta.abs].each {|pid| Process.kill("QUIT", pid)}
        else
          queue_pids.each {|pid| Process.kill("QUIT", pid)}
        end
      end
    end

    def worker_delta_for(queues)
      config.fetch(queues, 0) - workers.fetch(queues, []).size
    end

    def pids_for(queues)
      workers[queues].keys
    end

    def spawn_worker!(queues)
      worker = create_worker(queues)
      pid = fork do
        log "*** Starting worker #{worker}"
        call_after_prefork!
        reset_sig_handlers!
        #self_pipe.each {|io| io.close }
        begin
          worker.work(ENV['INTERVAL'] || DEFAULT_WORKER_INTERVAL) # interval, will block
        rescue Errno::EINTR
          log "Caught interrupted system call Errno::EINTR. Retrying."
          retry
        end
      end
      workers[queues] ||= {}
      workers[queues][pid] = worker
    end

    def create_worker(queues)
      queues = queues.to_s.split(',')
      worker = PooledWorker.new(*queues)
      worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
      worker.very_verbose = ENV['VVERBOSE']
      worker
    end

    # }}}

  end
end
