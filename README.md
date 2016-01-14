Resque Pool
===========

[![Build Status](https://travis-ci.org/nevans/resque-pool.png)](https://travis-ci.org/nevans/resque-pool)
[![Dependency Status](https://gemnasium.com/nevans/resque-pool.png)](https://gemnasium.com/nevans/resque-pool)

Resque pool is a daemon for managing a pool of
[resque](https://github.com/defunkt/resque) workers.  With a simple config file,
it manages your workers for you, starting up the appropriate number of workers
for each worker type.

Benefits
---------

* Less config - With a simple YAML file, you can start up a pool daemon, and it
  will monitor your workers for you.
* Less memory - If you are using ruby 2.0+ (with copy-on-write safe garbage
  collection), this should save you a *lot* of memory when you are managing many
  workers.
* Faster startup - when you start many workers at once, they would normally
  compete for CPU as they load their environments.  Resque-pool can load your
  application once, then rapidly fork the workers after setup.  If a worker
  crashes or is killed, a new worker will start up and take its place right away.

Upgrading?
-----------

See
[Changelog.md](https://github.com/nevans/resque-pool/blob/master/Changelog.md)
in case there are important or helpful changes.

How to use
-----------

### YAML file config

Create a `config/resque-pool.yml` (or `resque-pool.yml`) with your worker
counts.  The YAML file supports both using root level defaults as well as
environment specific overrides (`RACK_ENV`, `RAILS_ENV`, and `RESQUE_ENV`
environment variables can be used to determine environment).  For example in
`config/resque-pool.yml`:

```Yaml
foo: 1
bar: 2
"foo,bar,baz": 1

production:
  "foo,bar,baz": 4
```

### Rake task config

Require the rake tasks (`resque/pool/tasks`) in your `Rakefile`, load your
application environment, configure Resque as necessary, and configure
`resque:pool:setup` to disconnect all open files and sockets in the pool
manager and reconnect in the workers.  For example, with rails you should put
the following into `lib/tasks/resque.rake`:

```Ruby
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
```


For normal work with fresh resque and resque-scheduler gems add next lines in lib/rake/resque.rake

```ruby
task "resque:pool:setup" do
  Resque::Pool.after_prefork do |job|
    Resque.redis.client.reconnect
  end
end
```

### Start the pool manager

Then you can start the queues via:

    resque-pool --daemon --environment production

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

    resque    13858     1  0 13:44 ?        S      0:02 resque-pool-manager: managing [13867, 13875, 13871, 13872, 13868, 13870, 13876]
    resque    13867 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo
    resque    13868 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for bar
    resque    13870 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for bar
    resque    13871 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo,bar,baz
    resque    13872 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Forked 7481 at 1280343254
    resque     7481 13872  0 14:54 ?        S      0:00      \_ resque-1.9.9: Processing foo since 1280343254
    resque    13875 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Waiting for foo,bar,baz
    resque    13876 13858  0 13:44 ?        S      0:00  \_ resque-1.9.9: Forked 7485 at 1280343255
    resque     7485 13876  0 14:54 ?        S      0:00      \_ resque-1.9.9: Processing bar since 1280343254

Running as a daemon will default to placing the pidfile and logfiles in the
conventional rails locations, although you can configure that.  See
`resque-pool --help` for more options.

SIGNALS
-------

The pool manager responds to the following signals:

* `HUP`   - reset config loader (reload the config file), reload logfiles, restart all workers.
* `QUIT`  - gracefully shut down workers (via `QUIT`) and shutdown the manager
  after all workers are done.
* `INT`   - gracefully shut down workers (via `QUIT`) and immediately shutdown manager
* `TERM`  - immediately shut down workers (via `INT`) and immediately shutdown manager
  _(configurable via command line options)_
* `WINCH` - _(only when running as a daemon)_ send `QUIT` to each worker, but
  keep manager running (send `HUP` to reload config and restart workers)
* `USR1`/`USR2`/`CONT` - pass the signal on to all worker parents (see Resque docs).

Use `HUP` to help logrotate run smoothly and to change the number of workers
per worker type.  Signals can be sent via the `kill` command, e.g.
`kill -HUP $master_pid`

If the environment variable `TERM_CHILD` is set, `QUIT` and `TERM` will respond as
defined by Resque 1.22 and above. See http://hone.heroku.com/resque/2012/08/21/resque-signals.html
for details, overriding any command-line configuration for `TERM`. Setting `TERM_CHILD` tells
us you know what you're doing.

Custom Configuration Loader
---------------------------

If the static YAML file configuration approach does not meet your needs, you can
specify a custom configuration loader.

Set the `config_loader` class variable on Resque::Pool to an object that
responds to `#call` (which can simply be a lambda/Proc). The class attribute
needs to be set before starting the pool. This is usually accomplished
in the `resque:pool:setup` rake task, as described above.

For example, if you wanted to vary the number of worker processes based on a
value stored in Redis, you could do something like:

```ruby
task "resque:pool:setup" do
  Resque::Pool.config_loader = lambda do |env|
    worker_count = Redis.current.get("pool_workers_#{env}").to_i
    {"queueA,queueB" => worker_count }
  end
end
```

The configuration loader's `#call` method will be invoked about once a second.
This allows the configuration to constantly change, allowing you to scale the
number of workers up or down based on different conditions.
If the response is generally static, the loader may want to cache the value it
returns. It can optionally implement a `#reset!` method, which will be invoked
when the HUP signal is received, allowing the loader to flush its cache, or
perform any other re-initialization.

Zero-downtime code deploys
--------------------------

In a production environment you will likely want to manage the daemon using a
process supervisor like `runit` or `god` or an init system like `systemd` or
`upstart`.  Example configurations for some of these are included in the
`examples` directory.  With these systems, `reload` typically sends a `HUP`
signal, which will reload the configuration but not application code.  The
simplest way to make workers pick up new code after a deploy is to stop and
start the daemon.  This will result in a period where new jobs are not being
processed.

To avoid this downtime, leave the old pool running and start a new pool with
`resque-pool --hot-swap`.

The `--hot-swap` flag will turn off pidfiles (so multiple pools can run at
once), enable a lock file (so your init system knows when the pool is running),
and shut down other pools _after_ the workers have started for this pool.
These behaviors can also be configured separately (see `resque-pool --help`).
The `upstart` configs in the `examples` directory demonstrate how to supervise a
daemonized pool with hot swap.

Please be aware that this approach uses more memory than a simple restart, since
two copies of the application code are loaded at once. _TODO: [#139](https://github.com/nevans/resque-pool/issues/139)_

Other Features
--------------

You can also start a pool manager via `rake resque:pool` or from a plain old
ruby script by calling `Resque::Pool.run`.

Workers will watch the pool manager, and gracefully shutdown (after completing
their current job) if the manager process disappears before them.

You can specify an alternate config file by setting the `RESQUE_POOL_CONFIG` or
with the `--config` command line option.

See the `examples` directory for example `chef` cookbook and
`god` config.  In the `chef` cookbook, you can also find example `init.d` and
`muninrc` templates (all very out of date, pull requests welcome).

TODO
-----

See [the TODO list](https://github.com/nevans/resque-pool/issues) at github issues.

Contributors
-------------

See [list of contributors on github](https://github.com/nevans/resque-pool/graphs/contributors) or [in the changelog](https://github.com/nevans/resque-pool/blob/master/Changelog.md)
