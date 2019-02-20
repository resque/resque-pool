require "resque"
require "resque/pool"

module Resque
  class Pool
    module ConfigLoaders

      # Read/write pool config from redis.
      # Should be wrapped in +ConfigLoaders::Throttled+.
      #
      # n.b. The environment needs to be passed in up-front, and will be ignored
      # during +call+.
      class Redis
        attr_reader :redis
        attr_reader :app, :pool, :env, :name

        def initialize(app_name:    Pool.app_name,
                       pool_name:   Pool.pool_name,
                       environment: "unknown",
                       config_name: "config",
                       redis:       Resque.redis)
          @app   = app_name
          @pool  = pool_name
          @env   = environment
          @name  = config_name
          @redis = redis
        end

        # n.b. environment must be set up-front and will be ignored here.
        def call(_)
          redis.hgetall(key).tap do |h|
            h.each do |k,v|
              h[k] = v.to_i
            end
          end
        end

        # read individual worker config
        def [](worker)
          redis.hget(key, worker).to_i
        end

        # write individual worker config
        def []=(worker, count)
          redis.hset(key, worker, count.to_i)
        end

        # remove worker config
        def delete(worker)
          redis.multi do
            redis.hget(key, worker)
            redis.hdel(key, worker)
          end.first.to_i
        end

        # n.b. this is probably namespaced under +resque+
        def key
          @key ||= ["pool", "config", app, pool, env, name].join(":")
        end

      end

    end
  end
end
