# -*- encoding: utf-8 -*-
require 'resque/tasks'

namespace :resque do

  # resque worker config (not pool related).  e.g. hoptoad, rails environment
  task :setup

  namespace :pool do
     # resque pool config.  e.g. after_prefork connection handling
    task :setup
  end

  desc "Launch a pool of resque workers"
  task :pool => %w[resque:preload resque:setup resque:pool:setup] do
    require 'resque/pool'
    Resque::Pool.run
  end

end
