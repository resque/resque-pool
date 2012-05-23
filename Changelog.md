## 0.4.0.dev (unreleased)

 * ???

## 0.3.0 (2012-05-22)

This is mostly just a long overdue maintenance release.  Many pull requests were
merged.  A few non-pull-request branches were merged too.  This version supports
ruby 1.9.3, 1.8.7, and even ancient 1.8.6, and all are checked by
[travis-ci](http://travis-ci.org/nevans/resque-pool).  It also explicitly
supports resque ~> 1.20.  And (if you have `gem-man` installed), it now has man
pages for bin and yml config.

Many thanks to the contributers!

 * [@agnellvj](https://github.com/agnellvj): ruby 1.9 compatibility
 * [@geoffgarside](https://github.com/geoffgarside): man pages!
 * [@imajes](https://github.com/imajes) - bugfix: Handle when a pid no longer
   exists by the time you try and kill it.
 * [@jeremy](https://github.com/jeremy) & [@jamis](https://github.com/jamis) -
   tasks require `resque/pool` lazily
 * [@jhsu](https://github.com/jhsu) - bugfix: undefined variable 'e' for errors
 * [@gaffneyc](https://github.com/gaffneyc) - compatibility fix:
   Resque::Pool::PooledWorker as a module rather than class
 * [@kcrayon](https://github.com/kcrayon) - bugfix: fix worker shutdown
 * [@alexkwolfe](https://github.com/alexkwolfe) - added `app_name` for logging
   (and maybe more in the future?)

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
