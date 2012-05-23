module Resque
  class Pool
    module Logging
      extend self

      # more than a little bit complicated...
      # copied this from Unicorn.
      def self.reopen_logs!
        log "Flushing logs"
        [$stdout, $stderr].each do |fd|
          if fd.instance_of? File
            # skip if the file is the exact same inode and device
            orig_st = fd.stat
            begin
              cur_st = File.stat(fd.path)
              next if orig_st.ino == cur_st.ino && orig_st.dev == cur_st.dev
            rescue Errno::ENOENT
            end
            # match up the encoding
            open_arg = 'a'
            if fd.respond_to?(:external_encoding) && enc = fd.external_encoding
              open_arg << ":#{enc.to_s}"
              enc = fd.internal_encoding and open_arg << ":#{enc.to_s}"
            end
            # match up buffering (does reopen reset this?)
            sync = fd.sync
            # sync to disk
            fd.fsync
            # reopen, and set ruby buffering appropriately
            fd.reopen fd.path, open_arg
            fd.sync = sync
            log "Reopened logfile: #{fd.path}"
          end
        end
      end

      # Given a string, sets the procline ($0)
      # Procline is always in the format of:
      #   resque-pool-master: STRING
      def procline(string)
        $0 = "resque-pool-master#{app}: #{string}"
      end

      # TODO: make this use an actual logger
      def log(message)
        puts "resque-pool-manager#{app}[#{Process.pid}]: #{message}"
        #$stdout.fsync
      end

      # TODO: make this use an actual logger
      def log_worker(message)
        puts "resque-pool-worker#{app}[#{Process.pid}]: #{message}"
        #$stdout.fsync
      end

      # Include optional app name in procline
      def app
        app_name   = self.respond_to?(:app_name)       && self.app_name
        app_name ||= self.class.respond_to?(:app_name) && self.class.app_name
        app_name ? "[#{app_name}]" : ""
      end

    end
  end
end
