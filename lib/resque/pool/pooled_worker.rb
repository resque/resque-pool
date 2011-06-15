require 'resque/worker'

class Resque::Pool
  module PooledWorker

    def initialize(*args)
      @pool_master_pid = Process.pid
      super
    end

    def pool_master_has_gone_away?
      @pool_master_pid && @pool_master_pid != Process.ppid
    end

    # override +shutdown?+ method
    def shutdown?
      super || pool_master_has_gone_away?
    end

  end
end

Resque::Worker.class_eval do
  include Resque::Pool::PooledWorker
end
