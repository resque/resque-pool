require 'trollop'

module Resque
  class Pool
    module CLI
      extend self

      def run
        opts = optparse
        p opts
        daemonize if opts[:daemonize]
        redirect opts
        pidfile opts[:pidfile]
        start_pool
      end

      def optparse
        opts = Trollop::options do
          version "resque-pool #{Resque::Pool::VERSION} (c) nicholas a. evans"
          banner <<-EOS
resque-pool is the best way to manage a group (pool) of resque workers

Usage:
   resque-pool [options]
where [options] are:
          EOS
          opt :daemon, "Daemonize", :default => false
          opt :stdout, "Redirect stdout to logfile", :type => String, :short => '-o'
          opt :stderr, "Redirect stderr to logfile", :type => String, :short => '-e'
          opt :pidfile, "PID file location",         :type => String
        end
        if opts[:daemon]
          opts[:stdout]  ||= "resque-pool.stdout.log"
          opts[:stderr]  ||= "resque-pool.stderr.log"
          opts[:pidfile] ||= "resque-pool.pid"
        end
        opts
      end

      def redirect(opts)
        $stdout.reopen opts[:stdout], "a" if opts[:stdout] && !opts[:stdout].empty?
        $stderr.reopen opts[:stderr], "a" if opts[:stderr] && !opts[:stderr].empty?
      end

      def daemonize(opts)
        puts "daemonizing not implemented yet"
      end

      def pidfile(pidfile)
        pid = Process.pid
        if pidfile
          File.open pidfile, "w" do |f|
            f.write pid
          end
        end
        at_exit do
          if Process.pid == pid
            File.delete pidfile
          end
        end
      end

      def start_pool
        require 'rake'
        require 'resque/pool/tasks'
        Rake.application["resque:pool"].invoke
      end

    end
  end
end

