require "delegate"

module Resque
  class Pool

    module ConfigLoaders

      # Throttle the frequency of loading pool configuration
      # Defaults to call only once per 10 seconds.
      class Throttled < SimpleDelegator

        def initialize(config_loader, period: 10, time_source: Time)
          super(config_loader)
          @period = period
          @resettable = config_loader.respond_to?(:reset!)
          @last_check = 0
          @time_source = time_source
        end

        def call(env)
          # We do not need to cache per `env`, since the value of `env` will not
          # change during the life of the process.
          if (now > @last_check + @period)
            @cache = super
            @last_check = now
          end
          @cache
        end

        def reset!
          @last_check = 0
          super if @resettable
        end

        private

        def now
          @time_source.now.to_f
        end
      end

    end
  end
end
