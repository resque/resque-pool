require 'resque/pool/logging'

module Resque
  class Pool
    class MemoryManager
      include Logging

      attr_reader :hard_limit, :soft_limit

      def initialize(hard_limit=250, soft_limit=200)
        @hard_limit = hard_limit
        @soft_limit = soft_limit
      end

      def monitor_memory_usage(pool_manager)
        #only check every minute
        if @last_mem_check.nil? || @last_mem_check < Time.now - 60
          hard_kill_workers
          pool_manager.all_pids.each do |pid|
            total_usage  = memory_usage(pid)
            child_pid    = find_child_pid(pid)
            total_usage += memory_usage(child_pid) if child_pid

            if total_usage > hard_limit
              log "Terminating worker #{pid} for using #{total_usage}MB memory"
              stop_worker(pid)
            elsif total_usage > soft_limit
              log "Gracefully shutting down worker #{pid} for using #{total_usage}MB memory"
              stop_worker(pid, :QUIT)
            end
          end
          @last_mem_check = Time.now
        end
      end

      private

      def add_killed_worker(pid)
        @term_workers ||= []
        @term_workers << pid if pid
      end

      def find_child_pid(parent_pid)
        begin
          p = `ps --ppid #{parent_pid} -o pid --no-header`.to_i
          p == 0 ? nil : p
        rescue Errno::EINTR
          retry
        end
      end

      def hard_kill_workers
        @term_workers ||= []
        #look for workers that didn't terminate
        @term_workers.delete_if {|pid| !process_exists?(pid)}
        #send the rest a -9
        @term_workers.each {|pid| `kill -9 #{pid}`}
      end

      def hostname
        begin
          @hostname ||= `hostname`.strip
        rescue Errno::EINTR
          retry
        end
      end

      def memory_usage(pid)
        smaps_filename = "/proc/#{pid}/smaps"
        #Grab actual memory usage from proc in MB
        begin
          mem_usage = `
            if [ -f #{smaps_filename} ];
              then
                grep Private_Dirty #{smaps_filename} | awk '{s+=$2} END {printf("%d", s/1000)}'
              else echo "0"
            fi
          `.to_i
        rescue Errno::EINTR
          retry
        end
      end

      # TODO: DRY up this and the pidfile checker in Resque::Pool::CLI
      def process_exists?(pid)
        begin
          ps_line = `ps -p #{pid} --no-header`
        rescue Errno::EINTR
          retry
        end
        !ps_line.nil? && ps_line.strip != ''
      end

      def stop_worker(pid, signal=:TERM)
        begin
          worker = Resque.working.find do |w|
            host, worker_pid, queues = w.id.split(':')
            w if worker_pid.to_i == pid.to_i && host == hostname
          end
          if worker
            encoded_job = worker.job
            verb = signal == :QUIT ? 'Graceful' : 'Forcing'
            total_time = Time.now - Time.parse(encoded_job['run_at']) rescue 0
            log "#{verb} shutdown while processing: #{encoded_job} -- ran for #{'%.2f' % total_time}s"
          end
          Process.kill signal, pid
          if signal == :TERM
            add_killed_worker(pid)
            add_killed_worker(find_child_pid(pid))
          end
        rescue Errno::EINTR
          retry
        end
      end

    end
  end
end
