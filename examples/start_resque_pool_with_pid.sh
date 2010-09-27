#!/bin/sh
# This startup script takes one argument, the RAILS_ROOT, starts up
# resque-pool with logfiles and a pidfile, and returns immediately
# (resque-pool is backgrounded).  It should be run as the appuser.
#
# TODO: move all of the functionality of this file into the ruby script.

# The following environment variables are set explicitly here to ensure that
# they are set to exactly what I expect, no matter how the app is run.
# Setting these here may not be necessary for your environment.
export HOME=/home/appuser
# Make sure we are using the correct bundler with the correct ruby
BUNDLE='/opt/ruby-enterprise-1.8.6-20090610/bin/bundle'
export PATH=/opt/ruby-enterprise-1.8.6-20090610/bin:/usr/local/bin:/usr/bin:/bin

RAILS_ROOT=$1

# There's probably no compelling need to split stdout and stderr into two
# separate files.  Most of the time, resque doesn't send anything to stderr
# anyway.
STDOUT_FILE="$RAILS_ROOT/log/resque-pool.out.log"
STDERR_FILE="$RAILS_ROOT/log/resque-pool.err.log"
PID_FILE="$RAILS_ROOT/tmp/pids/resque-pool.pid"

export RAILS_ENV=production
#export VERBOSE=true
#export VVERBOSE=true

cd $RAILS_ROOT
$BUNDLE exec rake --trace resque:pool >> $STDOUT_FILE 2>> $STDERR_FILE &
echo $! > $PID_FILE
