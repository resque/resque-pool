require 'open3'

module Resque
  class Pool
    class Killer
      include Logging

      GRACEFUL_SHUTDOWN_SIGNAL=:INT

      def self.run
        new.run
      end

      def run
        my_pid = Process.pid
        pool_pids = all_resque_pool_processes
        pids_to_kill = pool_pids.reject{|pid| pid == my_pid}
        pids_to_kill.each do |pid|
          log "Pool (#{my_pid}) in kill-others mode: killing pool with pid (#{pid})"
          Process.kill(GRACEFUL_SHUTDOWN_SIGNAL, pid)
        end
      end


      def all_resque_pool_processes
        out, err, status = Open3.capture3("ps ax")
        unless status.success?
          raise "Unable to identify other pools: #{err}"
        end
        parse_pids_from_output out
      end

      def parse_pids_from_output(output)
        pool_lines = output.split("\n").grep(/resque-pool-master/)
        pool_lines.map{|line|
          line.split.first.to_i
        }.select{|pid| pid > 0}
      end
    end
  end
end
