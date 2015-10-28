module Resque
  class Pool
    module ConfigLoaders

      # Delegates to another loader.  Only calls the underlying loader once,
      # until/unless +reset!+ is called.
      class Memoized < SimpleDelegator
        def call(environment)
          @config ||= super
        end

        def reset!
          __get_obj__.reset! if __get_obj__.respond_to?(:reset!)
          @config = nil
        end
      end

    end
  end
end
