Experimental Features
---------------------

Features listed here should not cause you problems if you don't use them... and
probably won't cause you problems if you *do* use them.  Maybe.  We hope.  ;-)
Once these features have stood the test of time, can be trusted to work cross
platform, are well documented and tested, and has settled on a stable API, then
we'll stop calling them experimental and give them command line options.  Until
then, be forewarned that it might not work for you and the API might completely
change between each minor release.

### Memory management

If you set the `RESQUE_MEM_HARD_LIMIT` and `RESQUE_MEM_SOFT_LIMIT` environment
variables (in MB), then the manager will check once a minute to see if any of
your workers have exceeded these limits.  If a worker is over the soft limit it
will be sent a QUIT signal.  If a worker is over the hard signal it will be
sent a TERM signal, and if it is still running a minute later it will be sent a
KILL signal.

### Wait for orphaned workers to quit.

When restarting resque-pool, some orphaned workers may be left over from the
previous manager, even after the new manager has started up and forked its
workers.  If you set the `RESQUE_WAIT_FOR_ORPHANS` environment variable, then
the new manager will not start up all of its configured workers until all of
the orphaned workers have finished.  This might be useful for long running jobs
on memory constrained servers.

