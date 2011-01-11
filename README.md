Resque Pool
===========

Resque pool is a simple library for managing a pool of resque workers.  Given a
a config file (`resque-pool.yml` or `config/resque-pool.yml`), it will manage
your workers for you, starting up the appropriate number of workers for each.

Benefits
---------

* Less memory consumption - If you are using Ruby Enterprise Edition, or any
  ruby with copy-on-write safe garbage collection, this could save you a lot of
  memory when you are managing many workers.
* Simpler (less) config - If you are using monit or an init script to start up
  your workers, you can start up one pool, and it will manage your workers for
  you.
* Faster startup - if you are starting many workers at once, you would normally
  have them competing for CPU as they load their environments.  Resque-pool can
  load the environment once and almost instantaneously fork all of the workers.

How to use
-----------

To configure resque-pool, create a `config/resque-pool.yml` with your worker
counts.  To use resque-pool, require its rake tasks (`resque/pool/tasks`) in
your rake file, and run `resque-pool`

The YAML file supports both using root level defaults as well as environment
specific overrides (`RACK_ENV`, `RAILS_ENV`, and `RESQUE_ENV` environment
variables will be used to determine environment).  For example, to use
resque-pool with rails, in `config/resque-pool.yml`:

    foo: 1
    bar: 2
    "foo,bar,baz": 1

    production:
      "foo,bar,baz": 4

and in `lib/tasks/resque.rake`:

    require 'resque/pool/tasks'
    # this task will get called before resque:pool:setup
    # preload the rails environment in the pool master
    task "resque:setup" => :environment do
      # generic worker setup, e.g. Hoptoad for failed jobs
    end
    task "resque:pool:setup" do
      # close any sockets or files in pool master
      ActiveRecord::Base.connection.disconnect!
      # and re-open them in the resque worker parent
      Resque::Pool.after_prefork do |job|
        ActiveRecord::Base.establish_connection
      end
    end

Then you can start the queues via:

    resque-pool --environment production

This will start up seven worker processes, one exclusively for the foo queue,
two exclusively for the bar queue, and four workers looking at all queues in
priority.  This is similar to if you ran the following:

    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo &
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=bar &
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=bar &
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz &
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz &
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz &
    rake resque:work RAILS_ENV=production VERBOSE=1 QUEUES=foo,bar,baz &

Resque already forks for its own child processes.  The pool master will stay
around monitoring the resque worker parents, giving three levels: a single pool
master, many worker parents, and a worker child per worker (when the actual job
is being processed).  For example, `ps -ef f | grep [r]esque` (in Linux) might
return something like the following:

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

After a `HUP`, workers that are no longer needed will be gracefully shutdown
via `QUIT`.

Other Features
--------------

You can run resque-pool as a daemon via `--daemon`.  It will default to placing
the pidfile and logfiles in the rails default locations, and you may want to
configure that.  See `resque-pool --help` for more options.

An example init.d script and monitrc are provided in
`examples/chef_cookbook/templates/default`, as erb templates.  Just copy them
into place, filling in the erb variables as necessary.  An example chef recipe
is also provided (it should work at Engine Yard as is; just provide a
`/data/#{app_name}/shared/config/resque-pool.yml` on your utility servers).

You can also run `resque-pool` via the `resque:pool` rake task or from a plain
old ruby script by calling `Resque::Pool.run`.

Workers will watch the pool master, and gracefully shutdown (after completing
their current job) if the master process dies (for whatever reason) before
them.

You can specify an alternate config file by setting the `RESQUE_POOL_CONFIG`
environment variable like so:

    resque-pool -c /path/to/my/config.yml

TODO
-----

* cmd line option for non-rake loading
* cmd line option for preload ruby file
* provide Unix style log formatter
* web interface for adding and removing workers (etc)
* recover gracefully from a malformed config file (on startup and HUP)
* procline for malformed config file, graceful shutdown... and other states?
* figure out a good automated way to test this (cucumber or rspec?)
* clean up the code (I stole most of it from unicorn, and it's still a bit
  bastardized); excessive use of vim foldmarkers are a code smell.
* rename to `resque-squad`?
* rdoc
* incorporate resque-batchworker features? (v2.0)
* integrate with resque-scheduler? (v2.0)

Contributors
-------------

* John Schult (config file can be split by environment)
* Stephen Celis (increased gemspec sanity)
