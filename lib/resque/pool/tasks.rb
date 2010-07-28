# -*- encoding: utf-8 -*-

# require 'resque/pool/tasks'
# and configure "resque:setup" task to start up the environment, initialize
# RESQUE_POOL_CONFIG, and setup other resque hooks

namespace :resque do
  task :setup

  desc "Launch a pool of resque workers (set RESQUE_POOL_CONFIG)"
  task :pool => :setup do
    GC.respond_to?(:copy_on_write_friendly=) && GC.copy_on_write_friendly = true
    require 'resque/pool'
    config = if defined?(RESQUE_POOL_CONFIG)
               RESQUE_POOL_CONFIG
             elsif File.exist?("resque-pool.yml")
               "resque-pool.yml"
             elsif File.exist?("config/resque-pool.yml")
               "config/resque-pool.yml"
             else
               raise "No configuration found. Please setup config/resque-pool.yml"
             end
    Resque::Pool.new(config).start.join
  end

end
