Resque Pool
===========

Resque pool is a simple library for managing a pool of resque workers.  Given a
a config file, it manages your workers for you, starting up the appropriate
number of workers for each.

Benefits
---------

* Less config - With a simple YAML file, you can start up a pool daemon, and it
  will monitor your workers for you.  An example init.d script, monit config,
  and chef cookbook are provided.
* Less memory - If you are using Ruby Enterprise Edition, or any ruby with
  copy-on-write safe garbage collection, this should save you a lot of memory
  when you are managing many workers.
* Faster startup - when you start many workers at once, they would normally
  compete for CPU as they load their environments.  Resque-pool can load the
  environment once and almost instantaneously fork all of the workers.

How to use
-----------

### YAML file config

Create a `config/resque-pool.yml` with your worker counts.  The YAML file
supports both using root level defaults as well as environment specific
overrides (`RACK_ENV`, `RAILS_ENV`, and `RESQUE_ENV` environment variables can
be used to determine environment).  For example in `config/resque-pool.yml`:

    foo: 1
    bar: 2
    "foo,bar,baz": 1

    production:
      "foo,bar,baz": 4

### Rake task config

Require the rake tasks (`resque/pool/tasks`) in your rake file, configure
Resque as necessary, and configure `Resque::Pool` to disconnect all open
sockets in the pool manager and reconnect in the workers.  For example, with
rails you should put the following into `lib/tasks/resque.rake`:

    require 'resque/pool/tasks'
    # this task will get called before resque:pool:setup
    # and preload the rails environment in the pool manager
    task "resque:setup" => :environment do
      # generic worker setup, e.g. Hoptoad for failed jobs
    end
    task "resque:pool:setup" do
      # close any sockets or files in pool manager
      ActiveRecord::Base.connection.disconnect!
      # and re-open them in the resque worker parent
      Resque::Pool.after_prefork do |job|
        ActiveRecord::Base.establish_connection
      end
    end

### Start the pool manager

Then you can start the queues via:

    resque-pool --environment production

This will start up seven worker processes, one exclusively for the foo queue,
two exclusively for the bar queue, and four workers looking at all queues in
priority.  With the config above, this is similar to if you ran the following:

    rake resque:work RAILS_ENV=production QUEUES=foo &
    rake resque:work RAILS_ENV=production QUEUES=bar &
    rake resque:work RAILS_ENV=production QUEUES=bar &
    rake resque:work RAILS_ENV=production QUEUES=foo,bar,baz &
    rake resque:work RAILS_ENV=production QUEUES=foo,bar,baz &
    rake resque:work RAILS_ENV=production QUEUES=foo,bar,baz &
    rake resque:work RAILS_ENV=production QUEUES=foo,bar,baz &

The pool manager will stay around monitoring the resque worker parents, giving
three levels: a single pool manager, many worker parents, and one worker child
per worker (when the actual job is being processed).  For example, `ps -ef f |
grep [r]esque` (in Linux) might return something like the following:

    rails    13858     1  0 13:44 ?        S      0:02 resque-pool-manager: managing [13867, 13875, 13871, 13872, 13868, 13870, 13876]
    rails    13867 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo
    rails    13868 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for bar
    rails    13870 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for bar
    rails    13871 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo,bar,baz
    rails    13872 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Forked 7481 at 1280343254
    rails     7481 13872  0 14:54 ?        S      0:00      \_ resque-1.9.9: Processing foo since 1280343254
    rails    13875 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo,bar,baz
    rails    13876 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Forked 7485 at 1280343255
    rails     7485 13876  0 14:54 ?        S      0:00      \_ resque-1.9.9: Processing bar since 1280343254

You can also run resque-pool as a daemon via `--daemon`.  It will default to
placing the pidfile and logfiles in the rails default locations, which you may
want to configure.  The `RAILS_ENV` can be specified via `--environment`.  See
`resque-pool --help` for more options.

SIGNALS
-------

The pool manager responds to the following signals:

* `HUP`   - reload the config file, e.g. to change the number of workers per queue list
* `QUIT`  - send `QUIT` to each worker parent and shutdown the manager after all workers are done.
* `INT`   - send `QUIT` to each worker parent and immediately shutdown manager
* `TERM`  - send `TERM` to each worker parent and immediately shutdown manager
* `WINCH` - send `QUIT` to each worker, but keep manager running (send `HUP` to reload config and restart workers)
* `USR1`/`USR2`/`CONT` - send the signal on to all worker parents (see Resque docs).

After a `HUP`, workers that are no longer needed will be gracefully shutdown
via `QUIT`.

Other Features
--------------

An example chef recipe is provided (it should work at Engine Yard as is; just
provide a `/data/#{app_name}/shared/config/resque-pool.yml` on your utility
servers).  Even if you don't use chef, you can still use the example init.d
script and monitrc (erb templates) provided in
`examples/chef_cookbook/templates/default`.

You can also start a pool manager via `rake resque:pool` or from a plain old
ruby script by calling `Resque::Pool.run`.

Workers will watch the pool manager, and gracefully shutdown (after completing
their current job) if the manager process disappears before them.

You can specify an alternate config file by setting the `RESQUE_POOL_CONFIG` or
with the `--config` command line option.

TODO
-----

See [the TODO list](https://github.com/nevans/resque-pool/issues) at github issues.

Contributors
-------------

* John Schult (config file can be split by environment)
* Stephen Celis (increased gemspec sanity)
* Vincent Agnello, Robert Kamunyori, Paul Kauders; for pairing with me at
  B'more on Rails Open Source Hack Nights. :)
