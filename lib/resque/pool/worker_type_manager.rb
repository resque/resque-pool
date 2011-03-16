require 'resque/pool/logging'
require 'resque/pool/pooled_worker'

module Resque
  class Pool
    class WorkerTypeManager
      include Logging

      attr_reader :pool_manager, :queues, :queue_array

      def initialize(pool_manager, queues)
        @pool_manager = pool_manager
        @queues       = queues
        @queue_array  = queues.to_s.split(',')
      end

      # TODO: Pool manager will hold onto WorkerTypeManagers, and will push the
      # configuration directly into the WorkerTypeManagers
      def configuration
        { :count => pool_manager.config.fetch(queues, 0), }
      end

      def maintain_worker_count(offset)
        delta = worker_delta - offset
        spawn_missing_workers_for(delta) if delta > 0
        quit_excess_workers_for(delta)   if delta < 0
      end

      def pids
        running_workers.keys
      end

      # TODO: Pool manager will hold onto WorkerTypeManagers,
      # and WorkerTypeManager will store the workers itself
      def running_workers
        pool_manager.workers.fetch(queues, {})
      end

      def worker_delta
        configuration[:count] - running_workers.size
      end

      private

      def create_worker
        worker = PooledWorker.new(*queue_array)
        worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
        worker.very_verbose = ENV['VVERBOSE']
        worker
      end

      def quit_excess_workers_for(delta)
        if delta < 0
          queue_pids = pids.clone
          if queue_pids.size >= delta.abs
            queue_pids[0...delta.abs].each {|pid| Process.kill("QUIT", pid)}
          else
            queue_pids.each {|pid| Process.kill("QUIT", pid)}
          end
        end
      end

      # TODO: Pool manager will hold onto WorkerTypeManagers,
      # and WorkerTypeManager will store the pids itself
      def register_new_worker_with_manager(worker, pid)
        pool_manager.workers[queues] ||= {}
        pool_manager.workers[queues][pid] = worker
      end

      def reset_sig_handlers!
        QUEUE_SIGS.each {|sig| trap(sig, "DEFAULT") }
      end

      def spawn_missing_workers_for(delta)
        delta.times { spawn_worker! } if delta > 0
      end

      def spawn_worker!
        worker = create_worker
        pid = fork do
          start_forked_worker worker
        end
        register_new_worker_with_manager worker, pid
      end

      def start_forked_worker(worker)
        reset_sig_handlers!
        log_worker "Starting worker #{worker}"
        pool_manager.call_after_prefork!
        begin
          worker.work(ENV['INTERVAL'] || DEFAULT_WORKER_INTERVAL) # interval, will block
        rescue Errno::EINTR
          log_worker "Caught interrupted system call Errno::EINTR. Retrying."
          retry
        end
      end


    end
  end
end

