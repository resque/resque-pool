# TODO: reorganize code that is currently in resque/pool.rb into this file
require 'resque/pool/logging'

module Resque
  class Pool
    class Manager
      include Logging

    end
  end
end
