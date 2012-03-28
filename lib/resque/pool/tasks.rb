# -*- encoding: utf-8 -*-
require 'resque/tasks'
require 'resque/pool'
require 'resque/pool/cli'

namespace :resque do

  # resque worker config (not pool related).  e.g. hoptoad, rails environment
  task :setup

  namespace :pool do
     # resque pool config.  e.g. after_prefork connection handling
    task :setup do
      @opts = {:daemon => true}
      @opts[:stdout]  ||= "log/resque-pool.stdout.log"
      @opts[:stderr]  ||= "log/resque-pool.stderr.log"
      @opts[:pidfile] ||= "tmp/pids/resque-pool.pid"

      if defined?(Rails)
        Rake::Task[:environment].invoke
      elsif defined?(Sinatra)
        Sinatra::Application.environment = ENV['RACK_ENV']
      end
    end

    desc "Launch a pool of resque workers"
    task :start => %w[resque:setup resque:pool:setup] do
      if defined?(Rails)
        @opts.merge!(:environment => Rails.env)
      elsif defined?(Sinatra)
        @opts.merge!(:environment => ENV['RACK_ENV'])
      end

      Resque::Pool::CLI.run(@opts)
    end

    desc "Stop a pool of resque workers"
    task :stop => %w[resque:setup resque:pool:setup] do
      if File.exists?(@opts[:pidfile])
        pid = File.open(@opts[:pidfile]).read
        Process.kill :QUIT, pid.to_i
        puts "Stopped resque pool (pid #{pid})."
      else
        puts "resque-pool is not running"
      end
    end
  end

end
