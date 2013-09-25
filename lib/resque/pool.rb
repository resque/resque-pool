# -*- encoding: utf-8 -*-
require 'resque'
require 'resque/worker'
require 'resque/pool/version'
require 'resque/pool/logging'
require 'resque/pool/pooled_worker'
require 'erb'
require 'fcntl'
require 'yaml'

module Resque
  class Pool
    DEFAULT_OVERRIDE_PROC   = lambda { |config| config }
    SIG_QUEUE_MAX_SIZE      = 5
    DEFAULT_WORKER_INTERVAL = 5
    QUEUE_SIGS = [ :QUIT, :INT, :TERM, :USR1, :USR2, :CONT, :HUP, :WINCH, ]
    CHUNK_SIZE = (16 * 1024)

    include Logging
    extend  Logging
    attr_reader :config
    attr_reader :workers

    def initialize(configuration, config_proc = nil)
      init_config(configuration)
      @config_proc = config_proc || self.class.config_override
      @workers = Hash.new { |workers, queues| workers[queues] = {} }
      procline "(initialized)"
    end

    # Config Override:
    #
    def self.config_override
      @config_override || DEFAULT_OVERRIDE_PROC
    end

    def self.config_override=(override)
      if override.respond_to? :call
        @config_override = override
      else
        procline "Config override #{override.inspect} is not a callable object."
      end
    end

    # Config: after_prefork {{{

    # The `after_prefork` hooks will be run in workers if you are using the
    # preforking master worker to save memory. Use these hooks to reload
    # database connections and so forth to ensure that they're not shared
    # among workers.
    #
    # Call with a block to set a hook.
    # Call with no arguments to return all registered hooks.
    #
    def self.after_prefork(&block)
      @after_prefork ||= []
      block ? (@after_prefork << block) : @after_prefork
    end

    # Sets the after_prefork proc, clearing all pre-existing hooks.
    # Warning: you probably don't want to clear out the other hooks.
    # You can use `Resque::Pool.after_prefork << my_hook` instead.
    #
    def self.after_prefork=(after_prefork)
      @after_prefork = [after_prefork]
    end

    def call_after_prefork!
      self.class.after_prefork.each do |hook|
        hook.call
      end
    end

    # }}}
    # Config: class methods to start up the pool using the default config {{{

    @config_files = ["resque-pool.yml", "config/resque-pool.yml"]
    class << self; attr_accessor :config_files, :app_name; end

    def self.app_name
      @app_name ||= File.basename(Dir.pwd)
    end

    def self.handle_winch?
      @handle_winch ||= false
    end
    def self.handle_winch=(bool)
      @handle_winch = bool
    end

    def self.single_process_group=(bool)
      ENV["RESQUE_SINGLE_PGRP"] = !!bool ? "YES" : "NO"
    end
    def self.single_process_group
      %w[yes y true t 1 okay sure please].include?(
        ENV["RESQUE_SINGLE_PGRP"].to_s.downcase
      )
    end

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
      Resque::Pool.new(choose_config_file, config_override).start.join
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
        @config = YAML.load(ERB.new(IO.read(config_file)).result)
      else
        @config ||= {}
      end
      environment and @config[environment] and @config.merge!(@config[environment])
      @config.delete_if {|key, value| value.is_a? Hash }
    end

    def environment
      if defined? RAILS_ENV
        RAILS_ENV
      elsif defined?(Rails) && Rails.respond_to?(:env)
        Rails.env
      else
        ENV['RACK_ENV'] || ENV['RAILS_ENV'] || ENV['RESQUE_ENV']
      end
    end

    # }}}

    # Sig handlers and self pipe management {{{

    def self_pipe; @self_pipe ||= [] end
    def sig_queue; @sig_queue ||= [] end
    def term_child; @term_child ||= ENV['TERM_CHILD'] end


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

    def reset_sig_handlers!
      QUEUE_SIGS.each {|sig| trap(sig, "DEFAULT") }
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
        if term_child
          signal_all_workers(:TERM)
        else
          signal_all_workers(:QUIT)
        end
        log "HUP: new children will inherit new logfiles"
        maintain_worker_count
      when :WINCH
        if self.class.handle_winch?
          log "WINCH: gracefully stopping all workers"
          @config = {}
          maintain_worker_count
        end
      when :QUIT
        if term_child
          shutdown_everything_now!(signal)
        else
          graceful_worker_shutdown_and_wait!(signal)
        end
      when :INT
        graceful_worker_shutdown!(signal)
      when :TERM
        if term_child
          graceful_worker_shutdown!(signal)
        else
          case self.class.term_behavior
          when "graceful_worker_shutdown_and_wait"
            graceful_worker_shutdown_and_wait!(signal)
          when "graceful_worker_shutdown"
            graceful_worker_shutdown!(signal)
          else
            shutdown_everything_now!(signal)
          end
        end
      end
    end

    class << self
      attr_accessor :term_behavior
    end

    def graceful_worker_shutdown_and_wait!(signal)
      log "#{signal}: graceful shutdown, waiting for children"
      if term_child
        signal_all_workers(:TERM)
      else
        signal_all_workers(:QUIT)
      end
      reap_all_workers(0) # will hang until all workers are shutdown
      :break
    end

    def graceful_worker_shutdown!(signal)
      log "#{signal}: immediate shutdown (graceful worker shutdown)"
      if term_child
        signal_all_workers(:TERM)
      else
        signal_all_workers(:QUIT)
      end
      :break
    end

    def shutdown_everything_now!(signal)
      log "#{signal}: immediate shutdown (and immediate worker shutdown)"
      if term_child
        signal_all_workers(:QUIT)
      else
        signal_all_workers(:TERM)
      end
      :break
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
          break unless wpid

          if worker = delete_worker(wpid)
            log "Reaped resque worker[#{status.pid}] (status: #{status.exitstatus}) queues: #{worker.queues.join(",")}"
          else
            # this died before it could be killed, so it's not going to have any extra info
            log "Tried to reap worker [#{status.pid}], but it had already died. (status: #{status.exitstatus})"
          end
        end
      rescue Errno::ECHILD, QuitNowException
      end
    end

    # TODO: close any file descriptors connected to worker, if any
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
    # ???: maintain_worker_count, all_known_queues {{{

    def refresh_config
      cloned = @config.dup
      @config = @config_proc.call(@config)
    rescue => e
      log "There was an issue updating the configuration: #{e.message} #{e.backtrace.join("\n")}"
      cloned
    end

    def maintain_worker_count
      all_known_queues.each do |queues|
        delta = worker_delta_for(queues)
        spawn_missing_workers_for(queues) if delta > 0
        quit_excess_workers_for(queues)   if delta < 0
      end
    end

    def all_known_queues
      refresh_config
      config.keys | workers.keys
    end

    # }}}
    # methods that operate on a single grouping of queues {{{
    # perhaps this means a class is waiting to be extracted

    def spawn_missing_workers_for(queues)
      worker_delta_for(queues).times do |nr|
        spawn_worker!(queues)
      end
    end

    def quit_excess_workers_for(queues)
      delta = -worker_delta_for(queues)
      pids_for(queues)[0...delta].each do |pid|
        Process.kill("QUIT", pid)
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
        Process.setpgrp unless Resque::Pool.single_process_group
        log_worker "Starting worker #{worker}"
        call_after_prefork!
        reset_sig_handlers!
        #self_pipe.each {|io| io.close }
        worker.work(ENV['INTERVAL'] || DEFAULT_WORKER_INTERVAL) # interval, will block
      end
      workers[queues][pid] = worker
    end

    def create_worker(queues)
      queues = queues.to_s.split(',')
      worker = ::Resque::Worker.new(*queues)
      worker.term_timeout = ENV['RESQUE_TERM_TIMEOUT'] || 4.0
      worker.term_child = ENV['TERM_CHILD']
      if ENV['LOGGING'] || ENV['VERBOSE']
        worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
      end
      if ENV['VVERBOSE']
        worker.very_verbose = ENV['VVERBOSE']
      end
      worker
    end

    # }}}

  end
end
