# -*- encoding: utf-8 -*-

namespace :resque do
  task :setup

  desc "Launch a pool of resque workers"
  task :pool => :setup do
    require 'resque/pool'
    Resque::Pool.run
  end

end
