require 'resque/worker'

class Resque::Pool
  module PooledWorker

    def initialize_with_pool(*args)
      @pool_master_pid = Process.pid
      initialize_without_pool(*args)
    end

    def pool_master_has_gone_away?
      @pool_master_pid && @pool_master_pid != Process.ppid
    end

    def shutdown_with_pool?
      shutdown_without_pool? || pool_master_has_gone_away?
    end

    def self.included(base)
      base.instance_eval do
        alias_method :initialize_without_pool, :initialize
        alias_method :initialize, :initialize_with_pool
        alias_method :shutdown_without_pool?, :shutdown?
        alias_method :shutdown?, :shutdown_with_pool?
      end
    end

  end
end

Resque::Worker.class_eval do
  include Resque::Pool::PooledWorker
end
