require 'resque/pool/logging'

module Resque
  class Pool
    class OrphanWatcher
      include Logging

      attr_reader :pool_manager

      def initialize(pool_manager)
        @pool_manager = pool_manager
      end

      def worker_offset
          orphaned_worker_count / pool_manager.all_known_worker_types.size
      end

      def orphaned_worker_count
        if @last_orphaned_check.nil? || @last_orphaned_check < Time.now - 60
          if @orphaned_pids.nil?
            begin
              pids_with_parents = `ps -Af | grep resque | grep -v grep | grep -v resque-web | grep -v master | awk '{printf("%d %d\\n", $2, $3)}'`.split("\n")
            rescue Errno::EINTR
              retry
            end
            pids = pids_with_parents.collect {|x| x.split[0].to_i}
            parents = pids_with_parents.collect {|x| x.split[1].to_i}
            pids.delete_if {|x| parents.include?(x)}
            pids.delete_if {|x| all_pids.include?(x)}
            @orphaned_pids = pids
          elsif @orphaned_pids.size > 0
            @orphaned_pids.delete_if do |pid|
              begin
                ps_out = `ps --no-heading p #{pid}`
                ps_out.nil? || ps_out.strip == ''
              rescue Errno::EINTR
                retry
              end
            end
          end
          @last_orphaned_check = Time.now
          log "Current orphaned pids: #{@orphaned_pids}" if @orphaned_pids.size > 0
        end
        @orphaned_pids.size
      end

    end
  end
end
