module Resque
  class Pool

    # Namespace for various pre-packaged config loaders or loader decorators.
    module ConfigLoaders

      autoload :FileOrHashLoader, "resque/pool/config_loaders/file_or_hash_loader"
      autoload :Throttled,        "resque/pool/config_loaders/throttled"

    end
  end
end
