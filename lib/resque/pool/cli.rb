require 'trollop'
require 'resque/pool'
require 'resque/pool/logging'
require 'fileutils'

module Resque
  class Pool
    module CLI
      include Logging
      extend  Logging
      extend self

      def run
        opts = parse_options
        daemonize if opts[:daemon]
        manage_pidfile opts[:pidfile]
        redirect opts
        setup_environment opts
        set_pool_options opts
        start_pool
      end

      def parse_options
        opts = Trollop::options do
          version "resque-pool #{VERSION} (c) nicholas a. evans"
          banner <<-EOS
resque-pool is the best way to manage a group (pool) of resque workers

When daemonized, stdout and stderr default to resque-pool.stdxxx.log files in
the log directory and pidfile defaults to resque-pool.pid in the current dir.

Usage:
   resque-pool [options]
where [options] are:
          EOS
          opt :config, "Alternate path to config file", :type => String, :short => "-c"
          opt :appname, "Alternate appname",         :type => String,    :short => "-a"
          opt :daemon, "Run as a background daemon", :default => false,  :short => "-d"
          opt :stdout, "Redirect stdout to logfile", :type => String,    :short => '-o'
          opt :stderr, "Redirect stderr to logfile", :type => String,    :short => '-e'
          opt :nosync, "Don't sync logfiles on every write"
          opt :pidfile, "PID file location",         :type => String,    :short => "-p"
          opt :environment, "Set RAILS_ENV/RACK_ENV/RESQUE_ENV", :type => String, :short => "-E"
          opt :spawn_delay, "Delay in milliseconds between spawning missing workers", :type => Integer, :short => "-s"
          opt :term_graceful_wait, "On TERM signal, wait for workers to shut down gracefully"
          opt :term_graceful,      "On TERM signal, shut down workers gracefully"
          opt :term_immediate,     "On TERM signal, shut down workers immediately (default)"
          opt :single_process_group, "Workers remain in the same process group as the master", :default => false
        end
        if opts[:daemon]
          opts[:stdout]  ||= "log/resque-pool.stdout.log"
          opts[:stderr]  ||= "log/resque-pool.stderr.log"
          opts[:pidfile] ||= "tmp/pids/resque-pool.pid"
        end
        opts
      end

      def daemonize
        raise 'First fork failed' if (pid = fork) == -1
        exit unless pid.nil?
        Process.setsid
        raise 'Second fork failed' if (pid = fork) == -1
        exit unless pid.nil?
      end

      def manage_pidfile(pidfile)
        return unless pidfile
        pid = Process.pid
        if File.exist? pidfile
          if process_still_running? pidfile
            raise "Pidfile already exists at #{pidfile} and process is still running."
          else
            File.delete pidfile
          end
        else
          FileUtils.mkdir_p File.dirname(pidfile)
        end
        File.open pidfile, "w" do |f|
          f.write pid
        end
        at_exit do
          if Process.pid == pid
            File.delete pidfile
          end
        end
      end

      def process_still_running?(pidfile)
        old_pid = open(pidfile).read.strip.to_i
        Process.kill 0, old_pid
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      rescue ::Exception => e
        $stderr.puts "While checking if PID #{old_pid} is running, unexpected #{e.class}: #{e}"
        true
      end

      def redirect(opts)
        $stdin.reopen  '/dev/null'        if opts[:daemon]
        # need to reopen as File, or else Resque::Pool::Logging.reopen_logs! won't work
        out = File.new(opts[:stdout], "a") if opts[:stdout] && !opts[:stdout].empty?
        err = File.new(opts[:stderr], "a") if opts[:stderr] && !opts[:stderr].empty?
        $stdout.reopen out if out
        $stderr.reopen err if err
        $stdout.sync = $stderr.sync = true unless opts[:nosync]
      end

      # TODO: global variables are not the best way
      def set_pool_options(opts)
        if opts[:daemon]
          Resque::Pool.handle_winch = true
        end
        if opts[:term_graceful_wait]
          Resque::Pool.term_behavior = "graceful_worker_shutdown_and_wait"
        elsif opts[:term_graceful]
          Resque::Pool.term_behavior = "graceful_worker_shutdown"
        elsif ENV["TERM_CHILD"]
          log "TERM_CHILD enabled, so will user 'term-graceful-and-wait' behaviour"
          Resque::Pool.term_behavior = "graceful_worker_shutdown_and_wait"
        end
        if ENV.include?("DYNO") && !ENV["TERM_CHILD"]
          log "WARNING: Are you running on Heroku? You should probably set TERM_CHILD=1"
        end
        if opts[:spawn_delay]
          Resque::Pool.spawn_delay = opts[:spawn_delay] * 0.001
        end
      end

      def setup_environment(opts)
        Resque::Pool.app_name = opts[:appname]    if opts[:appname]
        ENV["RACK_ENV"] = ENV["RAILS_ENV"] = ENV["RESQUE_ENV"] = opts[:environment] if opts[:environment]
        Resque::Pool.log "Resque Pool running in #{ENV["RAILS_ENV"] || "development"} environment"
        ENV["RESQUE_POOL_CONFIG"] = opts[:config] if opts[:config]
        Resque::Pool.single_process_group = opts[:single_process_group]
      end

      def start_pool
        require 'rake'
        require 'resque/pool/tasks'
        Rake.application.init
        Rake.application.load_rakefile
        Rake.application["resque:pool"].invoke
      end

    end
  end
end

