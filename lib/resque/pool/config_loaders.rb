module Resque
  class Pool

    # Namespace for various pre-packaged config loaders or loader decorators.
    module ConfigLoaders

      autoload :FileOrHashLoader, "resque/pool/config_loaders/file_or_hash_loader"
      autoload :Redis,            "resque/pool/config_loaders/redis"
      autoload :Throttled,        "resque/pool/config_loaders/throttled"

    end
  end
end
