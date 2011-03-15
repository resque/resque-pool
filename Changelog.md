## unreleased

* bugfix: pidfile will be cleaned up on startup if old process was kill-9'd

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
