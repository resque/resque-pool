## _unreleased_
[full changelog](https://github.com/nevans/resque-pool/compare/v0.7.1...master).

* Removed CI testing for ruby 2.3 (EOL). Added for 2.7.

## 0.7.1 (2020-01-08)
[full changelog](https://github.com/nevans/resque-pool/compare/v0.7.0...v0.7.1).

Marked as compatible with rake 13, documentation fixes, and depfu updated
dependencies.

 * PR #183 [jcoyne](https://github.com/jcoyne) Rake 13 compatibility.
 * replace gemnasium badge with depfu, and use depfu for automated PRs
 * documentation updates: [jcoyne](https://github.com/jcoyne),
   [chaspy](https://github.com/chaspy), [budnik](https://github.com/budnik)

## 0.7.0 (2019-03-08)
[full changelog](https://github.com/nevans/resque-pool/compare/v0.6.0...v0.7.0).

The first new release in a _LONG_ time. Over three years! Sorry to everyone who
used git forks or master (instead of a rubygems release) during that time! So,
obviously the compatibility updates are important. But we also added
`--hot-swap`, `Resque::Pool::ConfigLoaders::Throttled`, bugfixes, and _big_
changes to the specs/CI to make it easier to push new releases.

Compatibility:
 * PR #160 [brucek](https://github.com/brucek) Rails 4 compatibility.
 * PR #171 [jrochkind](https::/github.com/jrochkind) resque 2.0.
 * PRs #174, #175:
   * update test deps (rspec, aruba, cucumber)
   * Only test/support rubies that aren't EOL (2.3, 2.4, 2.5, 2.6).

New features:
 * `--hot-swap` for [zero-downtime code
   deploys](https://github.com/nevans/resque-pool#zero-downtime-code-deploys).
   Thanks to [joshuaflanagan](https://github.com/joshuaflanagan),
   [brasic](https://github.com/brasic), and
   [ShippingEasy](https://github.com/ShippingEasy)!
 * [joshuaflanagan](https://github.com/joshuaflanagan) Add a throttled config
   loader, to wrap other config loaders (e.g. custom DB queries). See
   `Resque::Pool::ConfigLoaders::Throttled`.

Bugfixes:
 * PR #146 [kcrayon](https://github.com/kcrayon) Fix edge cases when old_pid is
   invalid.
 * PR #153 [jeremy](https://github.com/jeremy) Fix occasional deadlock from
   `Open3.capture3`.
 * PR #165 [pjambet](https://github.com/pjambet) Cast `RESQUE_TERM_TIMEOUT`
   to float.

And more (see the full changelog). Thanks also to contributions from:
[grosser](https://github.com/grosser), [msufa](https://github.com/msufa),
[dchandekstark](https://github.com/dchandekstark),

## 0.6.0 (2015-10-14)
[full changelog](https://github.com/nevans/resque-pool/compare/v0.5.0...v0.6.0).

One big new feature: [Custom Config
Loader](https://github.com/nevans/resque-pool#custom-configuration-loader)
thanks to [joshuaflanagan](https://github.com/joshuaflanagan)!

Lots of cleanup in this release.  Thanks to the contributers:

 * [joshuaflanagan](https://github.com/joshuaflanagan) Custom config loader
 * [grosser](https://github.com/grosser)
   * ship less files in the gem
   * remove trollop dependency
   * remove -n -t -r -n -i commandline options since they were added unintentionally
 * no longer hijacks shutdown for normal resque worker processes.
 * [PatrickTulskie](https://github.com/PatrickTulskie) Reopening log files now
   reopens *all* logs in memory (append write only; code copied from Unicorn)
 * [jonleighton](https://github.com/jonleighton) pass worker instance to
   `after_prefork` hook

## 0.5.0 (2015-03-24)

Some more merges of long outstanding pull requests.

 * _EVEN BETTER_ `TERM` support for Heroku than 0.4.0.  ;)
 * _DOCKER SUPPORT_ (don't go crazy when master pid is 1).
   _(example Dockerfile soon?)_
 * `--spawn_delay` option in case workers respawn too quickly
 * Support `RUN_AT_EXIT_HOOKS`.
 * And [more](https://github.com/nevans/resque-pool/compare/v0.4.0...v0.5.0).

Many thanks to the contributors! [JohnBat26](https://github.com/JohnBat26), Eric
Chapweske, [werkshy](https://github.com/werkshy),
[spajus](https://github.com/spajus), [greysteil](https://github.com/greysteil),
[tjsousa](https://github.com/tjsousa), [jkrall](https://github.com/jkrall),
[zmillman](https://github.com/zmillman), [nevans](http://github.com/nevans).

## 0.4.0 (2015-01-28)

Another _long_ overdue maintenance release.  Many users had been running the
various release candidates in production for over 16 months.  0.4.0 was based
on 0.4.0.rc2 and 0.4.0.rc3 was rolled up into 0.5.0 instead.

Better Heroku/`TERM_CHILD` support, better `upstart` process group control, ERB
in the config file, not-insane package size, and
[more](https://github.com/nevans/resque-pool/compare/v0.3.0...v0.4.0).

Many thanks to the contributors!

 * Better `TERM_CHILD` support (useful for Heroku or anywhere else that only
   sends `TERM` to quit) [@rayh](https://github.com/rayh) and
   [@jjulian](https://github.com/jjulian)
 * [@jjulian](https://github.com/jjulian):
   * 0.3.0 accidentally packaged up 13MB of extra files!  OOOPS... SORRY!
   * better MacOS X compatibility
   * missing LICENCE in gemspec
 * [@jasonrclark](https://github.com/jasonrclark): `after_prefork` hook manages
   an array of hooks, rather than one single hook
 * [@mlanett](https://github.com/mlanett): Parse ERB in the config file (_very_
   useful for hostname/environment switched configuration)
 * [@xjlu](https://github.com/xjlu): Match the task deps in resque:work
 * [@darbyfrey](https://github.com/darbyfrey): Fixing deprecation warnings in
   newer versions of resque
 * [@ewoodh20](https://github.com/ewoodh20): Use `Rails.env` if available
   (`RAILS_ENV` is deprecated)
 * [@dlackty](https://github.com/dlackty): example `god` config file
 * [@mattdbridges](https://github.com/mattdbridges): fix order dependent specs
 * [@nevans](https://github.com/nevans):
   * Ignore `WINCH` signal when running non-daemonized (often in the terminal)
   * Do not run children in the same process group (solves problems with `upstart`
     sending `TERM` to all processes at once)

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
