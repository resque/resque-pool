module Resque
  class Pool
    module ConfigLoaders

      # Delegates to another loader.
      # Merges any environment specific config, if available.
      class EnvironmentMerged < SimpleDelegator

        def call(environment)
          config = super.dup
          if env && config[env] && config[env].is_a?(Hash)
            config.merge!(config[env].dup)
          end
          config.delete_if {|key, value|
            !(key.is_a?(String) && value.is_a?(Fixnum))
          }
          config.freeze
        end

      end

    end
  end
end
