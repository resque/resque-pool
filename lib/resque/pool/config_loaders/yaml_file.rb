module Resque
  class Pool
    module ConfigLoaders

      # Loads a config hash from a YAML file, after processing it with ERB.
      # Will try default config file locations if no filename is provided.
      #
      # * wrap in Memoized to only load once.
      # * wrap in EnvironmentMerged to merge in the environment.
      #
      # e.g.
      #    Memoized.new(EnvironmentMerged.new(YamlFile.new(filename)))
      class YamlFile

        def initialize(filename=nil)
          @filename = filename
        end

        # Loads and processes file.
        def call(_)
          return {} unless filename
          raw  = IO.read(filename) # TODO: IO failure => {} with log error
          erb  = ERB.new(raw)      # TODO: ERB failure => {} with log error
          YAML.load(erb.result)
        end

      end

    end
  end
end
