require 'spec_helper'
require 'resque/pool/cli'

describe Resque::Pool::CLI do
  subject(:cli) { Resque::Pool::CLI }

  describe "option parsing" do
    it "`--daemon` sets the 'daemon' flag" do
      options = cli.parse_options(%w[--daemon])
      options[:daemon].should be_truthy
    end

    it "`--daemon` redirects stdout and stderr, when none specified" do
      options = cli.parse_options(%w[--daemon])
      options[:stdout].should == "log/resque-pool.stdout.log"
      options[:stderr].should == "log/resque-pool.stderr.log"
    end

    it "`--daemon` does not override provided stdout/stderr options" do
      options = cli.parse_options(%w[--stdout my.stdout --stderr my.stderr --daemon])
      options[:stdout].should == "my.stdout"
      options[:stderr].should == "my.stderr"
    end

    it "`--daemon` sets a default pidfile, when none specified" do
      options = cli.parse_options(%w[--daemon])
      options[:pidfile].should == "tmp/pids/resque-pool.pid"
    end

    it "`--daemon` does not override provided pidfile" do
      options = cli.parse_options(%w[--daemon --pidfile my.pid])
      options[:pidfile].should == "my.pid"
    end

    it "`--no-pidfile sets the 'no-pidfile' flag" do
      options = cli.parse_options(%w[--no-pidfile])
      options[:no_pidfile].should be_truthy
    end

    it "`--no-pidfile prevents `--daemon` from setting a default pidfile" do
      options = cli.parse_options(%w[--daemon --no-pidfile])
      options[:pidfile].should be_nil
    end

    it "`--no-pidfile` does not prevent explicit `--pidfile` setting" do
      options = cli.parse_options(%w[--no-pidfile --pidfile my.pid])
      options[:pidfile].should == "my.pid"
      options[:no_pidfile].should be_falsey
    end

    it "`--no-pidfile` overrides `--pidfile`" do
      options = cli.parse_options(%w[--pidfile my.pid --no-pidfile])
      options[:pidfile].should be_nil
      options[:no_pidfile].should be_truthy
    end

    it "`--hot-swap` enables `--no-pidfile --lock tmp/resque-pool.pid --kill-others`" do
      options = cli.parse_options(%w[--pidfile foo.pid --hot-swap])
      options[:pidfile].should be_nil
      options[:no_pidfile].should be_truthy
      options[:lock_file].should eq("tmp/resque-pool.lock")
      options[:killothers].should be_truthy
    end

    it "`--hot-swap` does not override `--lock`" do
      options = cli.parse_options(%w[--lock foo.lock --hot-swap])
      options[:lock_file].should eq("foo.lock")
    end

  end
end
