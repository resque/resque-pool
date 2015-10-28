module Resque
  class Pool
    module ConfigLoaders

      # Delegates to two loaders; the first with the default config and the
      # second with overrides.
      #
      # Merges the configs on every +call+.  Wrap in +Memoized+ or +Throttled+
      # to avoid that.
      class Overloaded

        def initialize(defaults, overloads)
          @defaults  = defaults
          @overloads = overloads
        end

        def call(env)
          @defaults.call(env).merge(@overloads.call(env))
        end

        def reset!
          @defaults.reset!  if @defaults.respond_to?(:reset!)
          @overloads.reset! if @overloads.respond_to?(:reset!)
        end

      end

    end
  end
end
