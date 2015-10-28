module Resque
  class Pool
    module ConfigLoaders

      # Will always return the same config hash.
      class Static
        def initialize(config)
          @config = config.dup.freeze
        end
        def call(_)
          @config
        end
      end

    end
  end
end
