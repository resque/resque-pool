## unreleased

* enhancement: new callbacks for configuration
  * `Resque::Pool.configure do |pool| ... end`
  * `pool.after_manager_wakeup`
  * `pool.to_calculate_worker_offset`
  * `pool.after_prefork` (instance callback prefered over class callback)
* experimental: memory management
* experimental: check orphaned workers
* development: a good bit of code cleanup and rearrangement

See ExperimentalFeatures.md for more info.  Thanks to Jason Haruska for these
features!

## 0.2.0 (2011-03-15)

* new feature: sending `HUP` to pool manager will reload the logfiles and
  gracefully restart all workers.
* enhancement: logging now includes timestamp, process "name" (worker or
  manager), and PID.
* enhancement: can be used with no config file or empty config file (not all
  *that* useful, but it's better than unceromoniously dieing!)
* bugfix: pidfile will be cleaned up on startup, e.g. if old process was
  kill-9'd (Jason Haruska)
* bugfix: TERM/INT are no longer ignored when HUP is waiting on children
* bugfix: `resque-pool -c config.yml` command line option was broken
* development: simple cucumber features for core functionality.
* upstream: depends on resque ~> 1.13

## 0.1.0 (2011-01-18)

* new feature: `resque-pool` command line interface
  * this replaces need for a special startup script.
  * manages PID file, logfiles, daemonizing, etc.
  * `resque-pool --help` for more info and options
* updated example config, init.d script, including a chef recipe that should
  work at EngineYard.

## 0.0.10 (2010-08-31)

* remove rubygems 1.3.6 dependency

## 0.0.9 (2010-08-26)

* new feature: `RESQUE_POOL_CONFIG` environment variable to set alt config file
* upgraded to resque 1.10, removing `Resque::Worker` monkeypatch

## 0.0.8 (2010-08-20)

* bugfix: using (or not using) environments in config file

## 0.0.7 (2010-08-16)

* new feature: split by environments in config file
* added example startup script, Rakefile, and monit config

## 0.0.5 (2010-06-29)

* bugfix: worker processes not shutting down after orphaned

## 0.0.4 (2010-06-29)

* first release used in production
