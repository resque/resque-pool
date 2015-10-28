module Resque
  class Pool
    module ConfigLoaders

      # Will load from a file (or from a hash), memoizing and merging in the
      # appropriate environment.
      class Default < SimpleDelegator
        extend Forwardable

        def initialize(filename_or_hash=nil)
          super(build_loader(filename_or_hash))
        end

        def build_loader(filename_or_hash) # :nodoc:
          loader = build_default(filename_or_hash)
          loader = EnvironmentMerged.new(loader)
          # TODO: save config to redis for remote inspection:
          #loader = Recorded.new(loader)
          loader = Memoized.new(loader)
          override = Redis.new(config_name: "override")
          loader = Overloaded.new(loader, override)
          loader = Throttled.new(loader)
        end

        def build_default(filename_or_hash) # :nodoc:
          case filename_or_hash
          when String, nil
            YamlFile.new(filename_or_hash || choose_config_file)
          when Hash
            Static.new(filename_or_hash)
          else
            raise(ArgumentError, "%s cannot be initialized with %p" % [
              self.class, filename_or_hash
            ])
          end
        end

        # If nil filename is provided, try the first of these that can be
        # found.
        DEFAULT_CONFIG_FILES = ["resque-pool.yml", "config/resque-pool.yml"]

        def choose_config_file # :nodoc:
          if ENV["RESQUE_POOL_CONFIG"]
            ENV["RESQUE_POOL_CONFIG"]
          else
            DEFAULT_CONFIG_FILES.detect { |f| File.exist?(f) }
          end
        end

      end

    end
  end
end
