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

To configure resque-pool, you can either set the `RESQUE_POOL_CONFIG` constant
to a hash in your `resque:setup` or you can set the same config in either
`resque-pool.yml` or `config/resque-pool.yml`.  To use resque-pool, require its
rake tasks in your rake file, and call the resque:pool task.  For example:

    require 'resque/pool/tasks'
    namespace :resque do
      task :setup do
        RESQUE_POOL_CONFIG = {
          'foo'         => 1,
          'bar'         => 1,
          'baz'         => 1,
          'foo,bar,baz' => 4,
        }
      end
    end

Then you can start the queues via:

    rake resque:pool

This will start up seven worker processes, one each looking exclusively at each
of the foo, bar, and baz queues, and four workers looking at all queues in
priority.  This is similar to if you manually ran the following:

    rake resque:worker QUEUES=foo
    rake resque:worker QUEUES=bar
    rake resque:worker QUEUES=baz
    rake resque:worker QUEUES=foo,bar,baz
    rake resque:worker QUEUES=foo,bar,baz
    rake resque:worker QUEUES=foo,bar,baz
    rake resque:worker QUEUES=foo,bar,baz


TODO
-----

* respond to HUP signal by reloading the config file and appropriately starting
  up and shutting down workers
* figure out a good way to test this
* clean up the code (I stole most of it from unicorn, and it's still a bit
  bastardized)
* children should watch for the parent, and gracefully die if parent disapears
  (normally parent will send SIGHUP on exit)

