require 'optparse'
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
        obtain_shared_lock opts[:lock_file]
        daemonize if opts[:daemon]
        manage_pidfile opts[:pidfile]
        redirect opts
        setup_environment opts
        set_pool_options opts
        start_pool
      end

      def parse_options(argv=nil)
        opts = {}
        parser = OptionParser.new do |opt|
          opt.banner = <<-EOS.gsub(/^            /, '')
            resque-pool is the best way to manage a group (pool) of resque workers

            When daemonized, stdout and stderr default to resque-pool.stdxxx.log files in
            the log directory and pidfile defaults to resque-pool.pid in the current dir.

            Usage:
               resque-pool [options]

            where [options] are:
          EOS
          opt.on('-c', '--config PATH', "Alternate path to config file") { |c| opts[:config] = c }
          opt.on('-a', '--appname NAME', "Alternate appname") { |c| opts[:appname] = c }
          opt.on("-d", '--daemon', "Run as a background daemon") {
            opts[:daemon] = true
            opts[:stdout]  ||= "log/resque-pool.stdout.log"
            opts[:stderr]  ||= "log/resque-pool.stderr.log"
            opts[:pidfile] ||= "tmp/pids/resque-pool.pid" unless opts[:no_pidfile]
          }
          opt.on("-k", '--kill-others', "Shutdown any other Resque Pools on startup") { opts[:killothers] = true }
          opt.on('-o', '--stdout FILE', "Redirect stdout to logfile") { |c| opts[:stdout] = c }
          opt.on('-e', '--stderr FILE', "Redirect stderr to logfile") { |c| opts[:stderr] = c }
          opt.on('--nosync', "Don't sync logfiles on every write") { opts[:nosync] = true }
          opt.on("-p", '--pidfile FILE', "PID file location") { |c|
            opts[:pidfile] = c
            opts[:no_pidfile] = false
          }
          opt.on('--no-pidfile', "Force no pidfile, even if daemonized") {
            opts[:pidfile] = nil
            opts[:no_pidfile] = true
          }
          opt.on('-l', '--lock FILE' "Open a shared lock on a file") { |c| opts[:lock_file] = c }
          opt.on("-H", "--hot-swap", "Set appropriate defaults to hot-swap a new pool for a running pool") {|c|
            opts[:pidfile] = nil
            opts[:no_pidfile] = true
            opts[:lock_file] ||= "tmp/resque-pool.lock"
            opts[:killothers] = true
          }
          opt.on("-E", '--environment ENVIRONMENT', "Set RAILS_ENV/RACK_ENV/RESQUE_ENV") { |c| opts[:environment] = c }
          opt.on("-s", '--spawn-delay MS', Integer, "Delay in milliseconds between spawning missing workers") { |c| opts[:spawn_delay] = c }
          opt.on('--term-graceful-wait', "On TERM signal, wait for workers to shut down gracefully") { opts[:term_graceful_wait] = true }
          opt.on('--term-graceful',      "On TERM signal, shut down workers gracefully") { opts[:term_graceful] = true }
          opt.on('--term-immediate',     "On TERM signal, shut down workers immediately (default)") { opts[:term_immediate] = true }
          opt.on('--single-process-group', "Workers remain in the same process group as the master") { opts[:single_process_group] = true }
          opt.on("-h", "--help", "Show this.") { puts opt; exit }
          opt.on("-v", "--version", "Show Version"){ puts "resque-pool #{VERSION} (c) nicholas a. evans"; exit}
        end
        parser.parse!(argv || parser.default_argv)

        opts
      end

      def daemonize
        raise 'First fork failed' if (pid = fork) == -1
        exit unless pid.nil?
        Process.setsid
        raise 'Second fork failed' if (pid = fork) == -1
        exit unless pid.nil?
      end

      # Obtain a lock on a file that will be held for the lifetime of
      # the process.  This aids in concurrent daemonized deployment with
      # process managers like upstart since multiple pools can share a
      # lock, but not a pidfile.
      def obtain_shared_lock(lock_path)
        return unless lock_path
        @lock_file = File.open(lock_path, 'w')
        unless @lock_file.flock(File::LOCK_SH)
          fail "unable to obtain shared lock on #{@lock_file}"
        end
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
        old_pid > 0 && Process.kill(0, old_pid)
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
          log "TERM_CHILD enabled, so will use 'term-graceful-and-wait' behaviour"
          Resque::Pool.term_behavior = "graceful_worker_shutdown_and_wait"
        end
        if ENV.include?("DYNO") && !ENV["TERM_CHILD"]
          log "WARNING: Are you running on Heroku? You should probably set TERM_CHILD=1"
        end
        if opts[:spawn_delay]
          Resque::Pool.spawn_delay = opts[:spawn_delay] * 0.001
        end
        Resque::Pool.kill_other_pools = !!opts[:killothers]
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
        self.const_set :RakeApp, Class.new(Rake::Application) {
          def default_task_name # :nodoc:
            "resque:pool"
          end
        }
        Rake.application = RakeApp.new
        require 'resque/pool/tasks'

        Rake.application.init
        Rake.application.load_rakefile
        Rake.application["resque:pool"].invoke
      end

    end
  end
end

