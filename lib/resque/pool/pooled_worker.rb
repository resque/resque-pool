require 'resque/worker'

class Resque::Pool
  module PooledWorker
    attr_accessor :pool_master_pid
    attr_accessor :worker_parent_pid

    # We can't just check if we've been re-parented to PID 1 (init) because we
    # want to support docker (which will make the pool master PID 1).
    #
    # We also check the worker_parent_pid, because resque-multi-jobs-fork calls
    # Worker#shutdown? from inside the worker child process.
    def pool_master_has_gone_away?
      not potential_parent_pids.include?(Process.ppid)
    end

    def potential_parent_pids
      [pool_master_pid, worker_parent_pid].compact
    end

    def shutdown_with_pool?
      shutdown_without_pool? || pool_master_has_gone_away?
    end

    def self.included(base)
      base.instance_eval do
        alias_method :shutdown_without_pool?, :shutdown?
        alias_method :shutdown?, :shutdown_with_pool?
      end
    end

  end
end

Resque::Worker.class_eval do
  include Resque::Pool::PooledWorker
end
