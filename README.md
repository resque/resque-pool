Resque Pool
===========

Resque pool is a simple library for managing a pool of resque workers.  Given a
configuration hash or a config file (resque-pool.yml or
config/resque-pool.yml), it will manage your workers for you, starting up the
appropriate number of workers for each.

Benefits
---------

* Less memory consumption - If you are using Ruby Enterprise Edition, or any
  ruby with copy-on-write safe garbage collection, this will save you a lot of
  memory when you managing many workers.
* Simpler (less) config - If you are using monit or god or an init script to
  start up your workers, you can simply start up one pool, and it will manage
  your workers for you.
* Faster startup - if you are starting many workers at once, you would normally
  have them competing for CPU as they load their environments.  Resque-pool can
  load the environment once, and almost immediately fork all of your workers.

How to use
-----------

To configure resque-pool, you can either set `Resque::Pool.config` to a hash in
your `resque:pool:setup` or you can set the same config in either
`resque-pool.yml` or `config/resque-pool.yml`.  To use resque-pool, require its
rake tasks in your rake file, and call the resque:pool task.

For example, to use resque-pool with rails, in `config/resque-pool.yml`:

    foo: 1
    bar: 2
    "foo,bar,baz": 4

and in `lib/tasks/resque.rake`:

    require 'resque/pool/tasks'

    # this task will get called before resque:pool:setup
    # preload the rails environment in the pool master
    task "resque:setup" => :environment do
      # generic worker setup, e.g. Hoptoad for failed jobs
    end

    # preload the rails environment in the pool master
    task "resque:pool:setup" do
      # it's better to use a config file, but you can also config here:
      # Resque::Pool.config = {"foo" => 1, "bar" => 1}

      # close any sockets or files in pool master
      ActiveRecord::Base.connection.disconnect!

      # and re-open them in the resque worker parent
      Resque::Pool.after_prefork do |job|
        ActiveRecord::Base.establish_connection
      end

      # you could also re-open them in the resque worker child, using
      # Resque.after_fork, but that probably isn't necessary, and
      # Resque::Pool.after_prefork should be faster, since it won't run
      # for every single job.
    end

Then you can start the queues via:

    rake resque:pool RAILS_ENV=production VERBOSE=1

This will start up seven worker processes, one each looking exclusively at each
of the foo, bar, and baz queues, and four workers looking at all queues in
priority.  This is similar to if you ran the following:

    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=bar
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=bar
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz

Resque already forks for its own child processes, giving two levels.  The pool
master will stay around monitoring the resque worker parents, giving three
levels:

* a single pool master
* many worker parents
* a worker child per worker (when the actual job is being processed)

For example, `ps -ef f | grep [r]esque` might return something like the
following:

    rails    13858     1  0 13:44 ?        S      0:02 resque-pool-master: managing [13867, 13875, 13871, 13872, 13868, 13870, 13876]
    rails    13867 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo
    rails    13868 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for bar
    rails    13870 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for bar
    rails    13871 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo,bar,baz
    rails    13872 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Forked 7481 at 1280343254
    rails     7481 13872  0 14:54 ?        S      0:00      \_ resque-1.9.9: Processing foo since 1280343254
    rails    13875 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo,bar,baz
    rails    13876 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Forked 7485 at 1280343255
    rails     7485 13876  0 14:54 ?        S      0:00      \_ resque-1.9.9: Processing bar since 1280343254

SIGNALS
-------

The pool master responds to the following signals:

* `HUP`   - reload the config file, e.g. to change the number of workers per queue list
* `QUIT`  - send `QUIT` to each worker parent and shutdown the master after all workers are done.
* `INT`   - send `QUIT` to each worker parent and immediately shutdown master
* `TERM`  - send `TERM` to each worker parent and immediately shutdown master
* `WINCH` - send `QUIT` to each worker, but keep master running (send `HUP` to reload config and restart workers)
* `USR1`/`USR2`/`CONT` - send the signal on to all worker parents (see Resque docs).

`HUP` will no-op if you use a hash for configuration instead of a config file.
So you should probably use a config file.  After a `HUP`, workers that are no
longer needed will be gracefully shutdown via `QUIT`.

Other Features
--------------

Workers will watch the pool master, and gracefully shutdown if the master
process dies (for whatever reason) before them.

TODO
-----

* do appropriate logging (e.g. all to one logfile, each queue to its own
  logfile, or each worker to its own logfile).  Logfile location must be
  configurable.
* (optionally) daemonize, setting a PID file somewhere
* recover gracefully from a malformed config file (on startup and HUP)
* figure out a good way to test this (preferably via cucumber or rspec)
* clean up the code (I stole most of it from unicorn, and it's still a bit
  bastardized)
* web interface for adding and removing workers (etc)
