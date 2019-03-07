require 'spec_helper'
require 'resque/pool/config_loaders/throttled'

module Resque::Pool::ConfigLoaders

  describe Throttled do
    let(:fake_time) { FakeTime.new 1445898807 }

    it "returns the config returned by the wrapped config loader for given env" do
      wrapped_config = {
        "dev" => {"qA,qB" => 1},
        "prd" => {"qA,qB" => 4}
      }
      wrapped_loader = lambda {|env| wrapped_config[env] }
      throttle = Throttled.new(wrapped_loader)

      expect(throttle.call("prd")).to eq({"qA,qB" => 4})
    end

    it "does not call wrapped loader again until the default period of time has elapsed" do
      wrapped_loader = TestConfigLoader.new
      wrapped_loader.configuration = {"qA,qB" => 1}

      throttle = Throttled.new(wrapped_loader, time_source: fake_time)
      first_call = throttle.call("prd")

      new_config = {"qA,qB" => 22}
      wrapped_loader.configuration = new_config
      fake_time.advance_time 6
      # config changed, but not enough time elapsed

      second_call = throttle.call("prd")

      expect(second_call).to eq(first_call)
      expect(wrapped_loader.times_called).to eq(1)

      fake_time.advance_time 6
      # now, enough time has elapsed to retrieve latest config

      third_call = throttle.call("prd")

      expect(third_call).to_not eq(first_call)
      expect(third_call).to eq(new_config)
      expect(wrapped_loader.times_called).to eq(2)

      # further calls continue to use cached value
      throttle.call("prd")
      throttle.call("prd")
      throttle.call("prd")
      expect(wrapped_loader.times_called).to eq(2)
    end

    it "can specify an alternate cache period" do
      config0 = {foo: 2, bar: 1}
      config1 = {bar: 3, baz: 9}
      config2 = {foo: 4, quux: 1}
      wrapped_loader = TestConfigLoader.new
      wrapped_loader.configuration = config0
      throttle = Throttled.new(
        wrapped_loader, period: 60, time_source: fake_time
      )
      expect(throttle.call("prd")).to eq(config0)
      wrapped_loader.configuration = config1
      fake_time.advance_time 59
      expect(throttle.call("prd")).to eq(config0)
      fake_time.advance_time 5
      expect(throttle.call("prd")).to eq(config1)
      wrapped_loader.configuration = config2
      fake_time.advance_time 59
      expect(throttle.call("prd")).to eq(config1)
      fake_time.advance_time 2
      expect(throttle.call("prd")).to eq(config2)
    end

    it "forces a call to the wrapperd loader after reset! called, even if required time hasn't elapsed" do
      wrapped_loader = TestConfigLoader.new
      wrapped_loader.configuration = {"qA,qB" => 1}

      throttle = Throttled.new(wrapped_loader, time_source: fake_time)
      throttle.call("prd")

      new_config = {"qA,qB" => 22}
      wrapped_loader.configuration = new_config
      fake_time.advance_time 6
      # the 10 second period has *not* elapsed

      throttle.reset!

      second_call = throttle.call("prd")

      expect(second_call).to eq(new_config)
      expect(wrapped_loader.times_called).to eq(2)
    end

    it "delegates reset! to the wrapped_loader, when supported" do
      wrapped_loader = TestConfigLoader.new
      throttle = Throttled.new(wrapped_loader)

      expect(wrapped_loader.times_reset).to eq(0)
      throttle.reset!
      expect(wrapped_loader.times_reset).to eq(1)
    end

    it "does not delegate reset! to the wrapped_loader when it is not supported" do
      wrapped_loader = lambda {|env| Hash.new }
      throttle = Throttled.new(wrapped_loader)

      expect {
        throttle.reset!
      }.to_not raise_error
    end

    class TestConfigLoader
      attr_accessor :configuration
      attr_reader :times_called
      attr_reader :times_reset

      def initialize
        @times_called = 0
        @times_reset = 0
      end

      def call(env)
        @times_called += 1
        configuration
      end

      def reset!
        @times_reset += 1
      end
    end

    class FakeTime
      attr_reader :now

      def initialize(start_time)
        @now = start_time
      end

      def advance_time(seconds)
        @now += seconds
      end
    end

  end

end
