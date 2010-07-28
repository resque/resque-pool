module Resque
  class Pool
    module Logging

      # Given a string, sets the procline ($0)
      # Procline is always in the format of:
      #   resque-pool-master: STRING
      def procline(string)
        $0 = "resque-pool-master: #{string}"
      end

      # TODO: make this use an actual logger
      def log(message)
        puts message
      end

    end
  end
end
