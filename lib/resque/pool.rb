require 'resque'
require 'fcntl'

module Resque
  class Pool
    attr_reader :pool_config
    attr_reader :workers

    SELF_PIPE = []
    SIG_QUEUE = []
    QUEUE_SIGS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, ]
    CHUNK_SIZE=(16 * 1024)

    def initialize(config)
      @pool_config = config.dup
      @workers = pool_config.keys.inject({}) {|h,k| h[k] = {}; h}
    end

    def init_self_pipe!
      SELF_PIPE.each { |io| io.close rescue nil }
      SELF_PIPE.replace(IO.pipe)
      SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
    end

    def init_sig_handlers!
      QUEUE_SIGS.each { |sig| trap_deferred(sig) }
      trap(:CHLD) { |_| awaken_master }
    end

    # defer a signal for later processing in #join (master process)
    def trap_deferred(signal)
      trap(signal) do |sig_nr|
        if SIG_QUEUE.size < 5
          SIG_QUEUE << signal
          awaken_master
        else
          puts "ignoring SIG#{signal}, queue=#{SIG_QUEUE.inspect}"
        end
      end
    end

    def start
      init_self_pipe!
      init_sig_handlers!
      maintain_worker_count
      puts "**** done in pool master #initialize"
      puts "**** Pool contains PIDs: #{all_pids.inspect}"
      self
    end

    def join
      loop do
        reap_all_workers
        break if handle_sig_queue! == :break
        maintain_worker_count if SIG_QUEUE.empty?
      end
      #stop # gracefully shutdown all workers on our way out
      puts "master complete"
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
      end
    end

    def reap_all_workers
      begin
        loop do
          wpid, status = Process.waitpid2(-1, Process::WNOHANG)
          wpid or break
          #if reexec_pid == wpid
            #puts "reaped #{status.inspect} exec()-ed"
            #self.reexec_pid = 0
            #self.pid = pid.chomp('.oldbin') if pid
            #proc_name 'master'
          #else
            worker = delete_worker(wpid) #and worker.tmp.close rescue nil
            puts "reaped #{status.inspect} " \
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
        next if (delta = worker_delta_for(queues)) == 0
        spawn_missing_workers_for(queues) if delta > 0
        #TODO: quit_excess_workers_for(queues)
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

    def worker_delta_for(queues)
      pool_config[queues] - workers[queues].size
    end

    def spawn_worker!(queues)
      worker = create_worker(queues)
      pid = fork do
        puts "*** Starting worker #{worker}"
        worker.work(ENV['INTERVAL'] || 5) # interval, will block
      end
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
