class Resque::Pool

  class PooledWorker < ::Resque::Worker

    def initialize(*args)
      @pool_master_pid = Process.pid
      super
    end

    def pool_master_has_gone_away?
      @pool_master_pid && @pool_master_pid != Process.ppid
    end

    # this allows us to shutdown
    def shutdown?
      @shutdown || pool_master_has_gone_away?
    end

    # this entire method (except for one line) is copied and pasted from
    # resque-1.9.9.  If shutdown were used as a method (attr_reader) rather
    # than an instance variable, I wouldn't need to reduplicate this. :-(
    #
    # hopefully I can get defunkt to accept my patch for this.
    # Until it is, the resque-pool gem will depend on an exact version of
    # resque.
    def work(interval = 5, &block)
      $0 = "resque: Starting"
      startup

      loop do
        #### THIS IS THE ONLY LINE THAT IS CHANGED
        break if shutdown?
        #### THAT WAS THE ONLY LINE THAT WAS CHANGED

        if not @paused and job = reserve
          log "got: #{job.inspect}"
          run_hook :before_fork
          working_on job

          if @child = fork
            rand # Reseeding
            procline "Forked #{@child} at #{Time.now.to_i}"
            Process.wait
          else
            procline "Processing #{job.queue} since #{Time.now.to_i}"
            perform(job, &block)
            exit! unless @cant_fork
          end

          done_working
          @child = nil
        else
          break if interval.to_i == 0
          log! "Sleeping for #{interval.to_i}"
          procline @paused ? "Paused" : "Waiting for #{@queues.join(',')}"
          sleep interval.to_i
        end
      end

    ensure
      unregister_worker
    end
  end

end
