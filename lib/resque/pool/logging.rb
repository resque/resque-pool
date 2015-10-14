module Resque
  class Pool
    module Logging
      extend self

      # This reopens ALL logfiles in the process that have been rotated
      # using logrotate(8) (without copytruncate) or similar tools.
      # A +File+ object is considered for reopening if it is:
      #   1) opened with the O_APPEND and O_WRONLY flags
      #   2) the current open file handle does not match its original open path
      #   3) unbuffered (as far as userspace buffering goes, not O_SYNC)
      # Returns the number of files reopened
      #
      # This was mostly copied from Unicorn 4.8.2 to simplify reopening
      # logs in the same way that Unicorn does.  Original comments and 
      # explanations are left intact.
      def self.reopen_logs!
        to_reopen      = [ ]
        reopened_count = 0

        ObjectSpace.each_object(File) { |fp| is_log?(fp) and to_reopen << fp }
        log "Flushing #{to_reopen.length} logs"

        to_reopen.each do |fp|
          orig_st = begin
            fp.stat
          rescue IOError, Errno::EBADF # race
            next
          end

          begin
            b = File.stat(fp.path)
            # Skip if reopening wouldn't do anything
            next if orig_st.ino == b.ino && orig_st.dev == b.dev
          rescue Errno::ENOENT
          end

          begin
            # stdin, stdout, stderr are special.  The following dance should
            # guarantee there is no window where `fp' is unwritable in MRI
            # (or any correct Ruby implementation).
            #
            # Fwiw, GVL has zero bearing here.  This is tricky because of
            # the unavoidable existence of stdio FILE * pointers for
            # std{in,out,err} in all programs which may use the standard C library
            if fp.fileno <= 2
              # We do not want to hit fclose(3)->dup(2) window for std{in,out,err}
              # MRI will use freopen(3) here internally on std{in,out,err}
              fp.reopen(fp.path, "a")
            else
              # We should not need this workaround, Ruby can be fixed:
              #    http://bugs.ruby-lang.org/issues/9036
              # MRI will not call call fclose(3) or freopen(3) here
              # since there's no associated std{in,out,err} FILE * pointer
              # This should atomically use dup3(2) (or dup2(2)) syscall
              File.open(fp.path, "a") { |tmpfp| fp.reopen(tmpfp) }
            end

            fp.sync = true
            fp.flush # IO#sync=true may not implicitly flush
            new_st = fp.stat

            # this should only happen in the master:
            if orig_st.uid != new_st.uid || orig_st.gid != new_st.gid
              fp.chown(orig_st.uid, orig_st.gid)
            end

            log "Reopened logfile: #{fp.path}"
            reopened_count += 1
          rescue IOError, Errno::EBADF
            # not much we can do...
          end
        end

        reopened_count
      end

      PROCLINE_PREFIX="resque-pool-master"

      # Given a string, sets the procline ($0)
      # Procline is always in the format of:
      #   resque-pool-master: STRING
      def procline(string)
        $0 = "#{PROCLINE_PREFIX}#{app}: #{string}"
      end

      # TODO: make this use an actual logger
      def log(message)
        return if $skip_logging
        puts "resque-pool-manager#{app}[#{Process.pid}]: #{message}"
        #$stdout.fsync
      end

      # TODO: make this use an actual logger
      def log_worker(message)
        return if $skip_logging
        puts "resque-pool-worker#{app}[#{Process.pid}]: #{message}"
        #$stdout.fsync
      end

      # Include optional app name in procline
      def app
        app_name   = self.respond_to?(:app_name)       && self.app_name
        app_name ||= self.class.respond_to?(:app_name) && self.class.app_name
        app_name ? "[#{app_name}]" : ""
      end

      private

      # Used by reopen_logs, borrowed from Unicorn...
      def self.is_log?(fp)
        append_flags = File::WRONLY | File::APPEND

        ! fp.closed? &&
          fp.stat.file? &&
          fp.sync &&
          (fp.fcntl(Fcntl::F_GETFL) & append_flags) == append_flags
        rescue IOError, Errno::EBADF
          false
      end

    end
  end
end
