# -*- encoding: utf-8 -*-

# require 'resque/pool/tasks'
# and configure "resque:setup" task to start up the environment, initialize
# RESQUE_POOL_CONFIG, and setup other resque hooks

namespace :resque do
  task :setup

  desc "Launch a pool of resque workers (set RESQUE_POOL_CONFIG)"
  task :pool => :setup do
    require 'resque/pool'
    Resque::Pool.new(RESQUE_POOL_CONFIG).start.join
  end

end
