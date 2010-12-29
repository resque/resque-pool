require 'resque/pool/queue_list_status'

module Resque
  class Pool

    class PoolStatus
      def initialize(pool_identifier)
        @pool_identifier = pool_identifier
      end

      def name; @pool_identifier; end

      def queue_lists
        %w[
          foo,bar
          foo
          bar
        ].map {|ql| QueueListStatus.new(@pool_identifier, ql) }
      end

      def reset!
        false
      end

    end

  end
end
