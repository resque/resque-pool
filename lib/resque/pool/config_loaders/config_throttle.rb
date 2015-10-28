module Resque
  class Pool

    module ConfigLoaders

      # Throttle the frequency of loading pool configuration
      class ConfigThrottle
        def initialize(period, config_loader, time_source: Time)
          @period = period
          @config_loader = config_loader
          @resettable = config_loader.respond_to?(:reset!)
          @last_check = 0
          @time_source = time_source
        end

        def call(env)
          # We do not need to cache per `env`, since the value of `env` will not
          # change during the life of the process.
          if (now > @last_check + @period)
            @cache = @config_loader.call(env)
            @last_check = now
          end
          @cache
        end

        def reset!
          @last_check = 0
          if @resettable
            @config_loader.reset!
          end
        end

        def now
          @time_source.now.to_f
        end
      end

    end
  end
end
