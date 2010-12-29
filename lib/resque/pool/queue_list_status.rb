module Resque
  class Pool

    class QueueListStatus

      def self.delete_all_keys!
        Resque.redis.keys("pool:queue_list_status:*").each do |k|
          Resque.redis.del k
        end
      end

      def initialize(pool_identifier, queue_list)
        @pool_identifier = pool_identifier
        @queue_list  = queue_list
      end

      def redis; Resque.redis; end

      def to_s; @queue_list; end

      def state
        "working"
      end

      def current_count
        3
      end

      def default_count
        3
      end

      def override_count
        Integer(redis.get(key_for_override) || default_count)
      end

      def incr!
        redis.setnx(key_for_override, default_count)
        redis.incr(key_for_override)
      end

      def decr!
        redis.setnx(key_for_override, default_count)
        if redis.decr(key_for_override) < 0
          redis.incr(key_for_override)
        end
      end

      private

      def key_for_override
        "pool:queue_list_status:#{@pool_identifier}:#{@queue_list}:override"
      end

    end

  end
end
