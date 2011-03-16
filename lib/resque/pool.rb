# -*- encoding: utf-8 -*-
require 'resque'
require 'resque/pool/version'
require 'resque/pool/logging'
require 'resque/pool/manager'
require 'resque/pool/worker_type_manager'
# experimental features!
require 'resque/pool/memory_manager'
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

    # Config: hooks {{{

    # The +configure+ block will be run once during pool startup, after the
    # internal initialization is complete, but before any workers are started
    # up.  This is for configuring any runtime callbacks that you want to
    # customize (e.g.  +after_wakup+, +worker_offset_handler+)
    #
    # Call with a block to set.
    # Call with no arguments to return the hook.
    def self.configure(&block)
      block ? (@configure = block) : @configure
    end

    def call_configure!
      self.class.configure && self.class.configure.call(self)
    end

    # The +after_manager_wakeup+ hook will be run in the pool manager every
    # time the pool manager wakes up from IO.select (normally once a second).
    # It will run immediately before the pool manager performs its normal
    # worker maintenance (starting and stopping workers as necessary).  If you
    # have some special logic for killing workers that are taking too long or
    # using too much memory, this is the place to put it.
    #
    # Call with a block to set the hook.
    # Call with no arguments to return the hook.
    def after_manager_wakeup(&block)
      block ? (@after_manager_wakeup = block) : @after_manager_wakeup
    end

    def call_after_manager_wakeup!
      after_manager_wakeup && after_manager_wakeup.call(self)
    end

    def to_calculate_worker_offset(&block)
      block ? (@to_calculate_worker_offset = block) : @to_calculate_worker_offset
    end

    # deprecated by instance level +after_prefork+ hook
    def self.after_prefork(&block)
      #log '"Resque::Pool.after_prefork(&blk)" is deprecated.'
      #log 'Please use "Resque::Pool.configure {|p| p.after_prefork(&blk) }" instead.'
      block ? (@after_prefork = block) : @after_prefork
    end

    # The +after_prefork+ hook will be run in workers if you are using the
    # preforking master worker to save memory. Use this hook to reload
    # database connections and so forth to ensure that they're not shared
    # among workers.
    #
    # Call with a block to set the hook.
    # Call with no arguments to return the hook.
    def after_prefork(&block)
      block ? (@after_prefork = block) : @after_prefork
    end

    # Set the after_prefork proc.
    def after_prefork=(after_prefork)
      @after_prefork = after_prefork
    end

    def call_after_prefork!
      (after_prefork && after_prefork.call) ||
        (self.class.after_prefork && self.class.after_prefork.call)
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

    class QuitNowException < Exception; end
    # defer a signal for later processing in #join (master process)
    def trap_deferred(signal)
      trap(signal) do |sig_nr|
        if @waiting_for_reaper && [:INT, :TERM].include?(signal)
          log "Recieved #{signal}: short circuiting QUIT waitpid"
          raise QuitNowException
        end
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
        log "HUP: reload config file and reload logfiles"
        load_config
        Logging.reopen_logs!
        log "HUP: gracefully shutdown old children (which have old logfiles open)"
        signal_all_workers(:QUIT)
        log "HUP: new children will inherit new logfiles"
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
      procline("(configuring)")
      call_configure!
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
          call_after_manager_wakeup!
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
      @waiting_for_reaper = waitpid_flags == 0
      begin
        loop do
          # -1, wait for any child process
          wpid, status = Process.waitpid2(-1, waitpid_flags)
          wpid or break
          worker = delete_worker(wpid)
          # TODO: close any file descriptors connected to worker, if any
          log "Reaped resque worker[#{status.pid}] (status: #{status.exitstatus}) queues: #{worker.queues.join(",")}"
        end
      rescue Errno::EINTR
        retry
      rescue Errno::ECHILD, QuitNowException
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
      to_calculate_worker_offset && to_calculate_worker_offset.call || 0
    end

    # }}}

  end
end
