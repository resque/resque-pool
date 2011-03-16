Experimental Features
---------------------

Features listed here should not cause you problems if you don't use them... and
probably won't cause you problems if you *do* use them.  Maybe.  We hope.  ;-)
Once these features have stood the test of time, can be trusted to work cross
platform, are well documented and tested, and have settled on a stable API,
then we'll stop calling them experimental and probably give them command line
options.  Until then, be forewarned that it might not work for you and the API
might change between minor releases.

### Memory management

A memory manager is provided which can check once a minute to see if any of
your workers are using too much memory.  If a worker is over the soft limit it
will be sent a QUIT signal.  If a worker is over the hard signal it will be
sent a TERM signal, and if it is still running a minute later it will be sent a
KILL signal.  To use the memory manager, add something like the following to
your Rakefile config:

    task "resque:pool:setup" do
      Resque::Pool.configure do |pool|
        # memory limits are in MB
        hard_limit = 250
        soft_limit = 200
        mm = Resque::Pool::MemoryManager.new(pool, hard_limit, soft_limit)
        pool.after_manager_wakeup { mm.monitor_memory_usage }
      end
    end

### Wait for orphaned workers to quit.

When restarting resque-pool, some orphaned workers may be left over from the
previous manager, even after the new manager has started up and forked its
workers.  If you set the `RESQUE_WAIT_FOR_ORPHANS` environment variable, then
the new manager will not start up all of its configured workers until all of
the orphaned workers have finished.  This might be useful for long running jobs
on memory constrained servers.

To use this, add something like the following to your Rakefile config:

    task "resque:pool:setup" do
      Resque::Pool.configure do |pool|
        orphan_watcher = Resque::Pool::OrphanWatcher.new(pool)
        pool.to_calculate_worker_offset { orphan_watcher.worker_offset }
      end
    end

