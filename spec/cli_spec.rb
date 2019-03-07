require 'spec_helper'
require 'resque/pool/cli'

describe Resque::Pool::CLI do
  subject(:cli) { Resque::Pool::CLI }

  describe "option parsing" do
    it "`--daemon` sets the 'daemon' flag" do
      options = cli.parse_options(%w[--daemon])
      expect(options[:daemon]).to be_truthy
    end

    it "`--daemon` redirects stdout and stderr, when none specified" do
      options = cli.parse_options(%w[--daemon])
      expect(options[:stdout]).to eq "log/resque-pool.stdout.log"
      expect(options[:stderr]).to eq "log/resque-pool.stderr.log"
    end

    it "`--daemon` does not override provided stdout/stderr options" do
      options = cli.parse_options(%w[--stdout my.stdout --stderr my.stderr --daemon])
      expect(options[:stdout]).to eq "my.stdout"
      expect(options[:stderr]).to eq "my.stderr"
    end

    it "`--daemon` sets a default pidfile, when none specified" do
      options = cli.parse_options(%w[--daemon])
      expect(options[:pidfile]).to eq "tmp/pids/resque-pool.pid"
    end

    it "`--daemon` does not override provided pidfile" do
      options = cli.parse_options(%w[--daemon --pidfile my.pid])
      expect(options[:pidfile]).to eq "my.pid"
    end

    it "`--no-pidfile sets the 'no-pidfile' flag" do
      options = cli.parse_options(%w[--no-pidfile])
      expect(options[:no_pidfile]).to be_truthy
    end

    it "`--no-pidfile prevents `--daemon` from setting a default pidfile" do
      options = cli.parse_options(%w[--daemon --no-pidfile])
      expect(options[:pidfile]).to be_nil
    end

    it "`--no-pidfile` does not prevent explicit `--pidfile` setting" do
      options = cli.parse_options(%w[--no-pidfile --pidfile my.pid])
      expect(options[:pidfile]).to eq "my.pid"
      expect(options[:no_pidfile]).to be_falsey
    end

    it "`--no-pidfile` overrides `--pidfile`" do
      options = cli.parse_options(%w[--pidfile my.pid --no-pidfile])
      expect(options[:pidfile]).to be_nil
      expect(options[:no_pidfile]).to be_truthy
    end

    it "`--hot-swap` enables `--no-pidfile --lock tmp/resque-pool.pid --kill-others`" do
      options = cli.parse_options(%w[--pidfile foo.pid --hot-swap])
      expect(options[:pidfile]).to be_nil
      expect(options[:no_pidfile]).to be_truthy
      expect(options[:lock_file]).to eq("tmp/resque-pool.lock")
      expect(options[:killothers]).to be_truthy
    end

    it "`--hot-swap` does not override `--lock`" do
      options = cli.parse_options(%w[--lock foo.lock --hot-swap])
      expect(options[:lock_file]).to eq("foo.lock")
    end

  end
end
