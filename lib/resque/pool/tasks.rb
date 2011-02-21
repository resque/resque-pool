# -*- encoding: utf-8 -*-
require 'resque/tasks'
require 'resque/pool'

namespace :resque do

  # resque worker config (not pool related).  e.g. hoptoad, rails environment
  task :setup

  namespace :pool do
     # resque pool config.  e.g. after_prefork connection handling
    task :setup
  end

  desc "Launch a pool of resque workers"
  task :pool => %w[resque:setup resque:pool:setup] do
    Resque::Pool.run
  end

end
