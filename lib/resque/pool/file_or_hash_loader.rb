module Resque
  class Pool
    class FileOrHashLoader
      def initialize(filename_or_hash=nil)
        case filename_or_hash
        when String, nil
          @filename = filename_or_hash
        when Hash
          @static_config = filename_or_hash.dup
        else
          raise "#{self.class} cannot be initialized with #{filename_or_hash.inspect}"
        end
      end

      def call(environment)
        @config ||= load_config_from_file(environment)
      end

      def reset!
        @config = nil
      end

      private

      def load_config_from_file(environment)
        if @static_config
          new_config = @static_config
        else
          filename = config_filename
          new_config = load_config filename
        end
        apply_environment new_config, environment
      end

      def apply_environment(config, environment)
        environment and config[environment] and config.merge!(config[environment])
        config.delete_if {|key, value| value.is_a? Hash }
      end

      def config_filename
        @filename || choose_config_file
      end

      def load_config(filename)
        return {} unless filename
        YAML.load(ERB.new(IO.read(filename)).result)
      end

      CONFIG_FILES = ["resque-pool.yml", "config/resque-pool.yml"]
      def choose_config_file
        if ENV["RESQUE_POOL_CONFIG"]
          ENV["RESQUE_POOL_CONFIG"]
        else
          CONFIG_FILES.detect { |f| File.exist?(f) }
        end
      end
    end
  end
end
