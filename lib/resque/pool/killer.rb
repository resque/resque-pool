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
        out, err, status = Open3.capture3("ps -e -o pid= -o command=")
        unless status.success?
          raise "Unable to identify other pools: #{err}"
        end
        parse_pids_from_output out
      end

      RESQUE_POOL_PIDS = /
        ^\s*(\d+)                         # PID digits, optional leading spaces
        \s+                               # column divider
        #{Regexp.escape(PROCLINE_PREFIX)} # exact match at start of command
      /x

      def parse_pids_from_output(output)
        output.scan(RESQUE_POOL_PIDS).flatten.map(&:to_i)
      end
    end
  end
end
