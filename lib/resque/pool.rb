# -*- encoding: utf-8 -*-
require 'resque'
require 'resque/pool/version'
require 'resque/pool/logging'
require 'resque/pool/pooled_worker'
require 'resque/pool/manager'
require 'resque/pool/worker_type_manager'

require 'resque/pool/orphan_watcher'

require 'fcntl'
require 'yaml'

module Resque
  class Pool
    SIG_QUEUE_MAX_SIZE = 5
    DEFAULT_WORKER_INTERVAL = 5
    QUEUE_SIGS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :CONT, :HUP, :WINCH, ]
    CHUNK_SIZE = (16 * 1024)

    include Logging
    attr_reader :config
    attr_reader :workers

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

    def config_file
      @config_file || (!@config && ::Resque::Pool.choose_config_file)
    end

    def init_config(config)
      case config
      when String, nil
        @config_file = config
      else
        @config = config.dup
      end
      load_config
    end

    def load_config
      if config_file
        @config = YAML.load_file(config_file)
      else
        @config ||= {}
      end
      environment and @config[environment] and config.merge!(@config[environment])
      config.delete_if {|key, value| value.is_a? Hash }
    end

    def environment
      if defined? Rails
        Rails.env
      elsif defined? RAILS_ENV # keep compatibility with older versions of rails
        RAILS_ENV
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
      log "started manager"
      report_worker_pool_pids
      self
    end

    def report_worker_pool_pids
      if workers.empty?
        log "Pool is empty"
      else
        log "Pool contains worker PIDs: #{all_pids.inspect}"
      end
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
      log "manager finished"
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
          log "Reaped resque worker[#{status.pid}] (status: #{status.exitstatus}) queues: #{worker.queues.join(",")}"
        end
      rescue Errno::EINTR
        retry
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

    def memory_usage(pid)
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
    end

    def process_exists?(pid)
      begin
        ps_line = `ps -p #{pid} --no-header`
      rescue Errno::EINTR
        retry
      end
      !ps_line.nil? && ps_line.strip != ''
    end

    def hard_kill_workers
      @term_workers ||= []
      #look for workers that didn't terminate
      @term_workers.delete_if {|pid| !process_exists?(pid)}
      #send the rest a -9
      @term_workers.each {|pid| `kill -9 #{pid}`}
    end

    def add_killed_worker(pid)
      @term_workers ||= []
      @term_workers << pid if pid
    end

    def monitor_memory_usage
      return unless ENV["RESQUE_MEM_HARD_LIMIT"] && ENV["RESQUE_MEM_SOFT_LIMIT"]
      hard_limit = ENV["RESQUE_MEM_HARD_LIMIT"]
      soft_limit = ENV["RESQUE_MEM_SOFT_LIMIT"]
      #only check every minute
      if @last_mem_check.nil? || @last_mem_check < Time.now - 60
        hard_kill_workers
        all_pids.each do |pid|
          total_usage = memory_usage(pid)
          child_pid = find_child_pid(pid)
          
          total_usage += memory_usage(child_pid) if child_pid
          
          if total_usage > hard_limit
            log "Terminating worker #{pid} for using #{total_usage}MB memory"
            stop_worker(pid)
          elsif total_usage > soft_limit
            log "Gracefully shutting down worker #{pid} for using #{total_usage}MB memory"
            stop_worker(pid, :QUIT)
          end
        end
        @last_mem_check = Time.now
      end
    end

    def hostname
      begin
        @hostname ||= `hostname`.strip
      rescue Errno::EINTR
        retry
      end
    end

    def stop_worker(pid, signal=:TERM)
      begin
        worker = Resque.working.find do |w|
          host, worker_pid, queues = w.id.split(':')
          w if worker_pid.to_i == pid.to_i && host == hostname
        end
        if worker
          encoded_job = worker.job
          verb = signal == :QUIT ? 'Graceful' : 'Forcing'
          total_time = Time.now - Time.parse(encoded_job['run_at']) rescue 0
          log "#{verb} shutdown while processing: #{encoded_job} -- ran for #{'%.2f' % total_time}s"
        end
        Process.kill signal, pid
        if signal == :TERM
          add_killed_worker(pid)
          add_killed_worker(find_child_pid(pid))
        end
      rescue Errno::EINTR
        retry
      end
    end

    def find_child_pid(parent_pid)
      begin
        p = `ps --ppid #{parent_pid} -o pid --no-header`.to_i
        p == 0 ? nil : p
      rescue Errno::EINTR
        retry
      end
    end

    # }}}
    # maintain_worker_count, all_known_worker_types, worker_offset {{{

    def maintain_worker_count
      all_known_worker_types.each do |queues|
        WorkerTypeManager.new(self, queues).maintain_worker_count(worker_offset)
      end
    end

    def all_known_worker_types
      config.keys | workers.keys
    end

    def worker_offset
      if ENV["RESQUE_WAIT_FOR_ORPHANS"]
        OrphanWatcher.new(self).worker_offset
      else
        0
      end
    end

    # }}}

  end
end
