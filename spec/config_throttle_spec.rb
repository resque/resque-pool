require 'spec_helper'
require 'resque/pool/config_throttle'

describe Resque::Pool::ConfigThrottle do
  let(:fake_time) { FakeTime.new 1445898807 }

  it "returns the config returned by the wrapped config loader for given env" do
    wrapped_config = {
      "dev" => {"qA,qB" => 1},
      "prd" => {"qA,qB" => 4}
    }
    wrapped_loader = lambda {|env| wrapped_config[env] }
    throttle = Resque::Pool::ConfigThrottle.new(10, wrapped_loader)

    throttle.call("prd").should eq({"qA,qB" => 4})
  end

  it "does not call wrapped loader again until the specified period of time has elapsed" do
    wrapped_loader = TestConfigLoader.new
    wrapped_loader.configuration = {"qA,qB" => 1}

    throttle = Resque::Pool::ConfigThrottle.new(10, wrapped_loader, time_source: fake_time)
    first_call = throttle.call("prd")

    new_config = {"qA,qB" => 22}
    wrapped_loader.configuration = new_config
    fake_time.advance_time 6
    # config changed, but not enough time elapsed

    second_call = throttle.call("prd")

    second_call.should eq(first_call)
    wrapped_loader.times_called.should == 1

    fake_time.advance_time 6
    # now, enough time has elapsed to retrieve latest config

    third_call = throttle.call("prd")

    third_call.should_not eq(first_call)
    third_call.should eq(new_config)
    wrapped_loader.times_called.should == 2

    # further calls continue to use cached value
    throttle.call("prd")
    throttle.call("prd")
    throttle.call("prd")
    wrapped_loader.times_called.should == 2
  end

  it "forces a call to the wrapperd loader after reset! called, even if required time hasn't elapsed" do
    wrapped_loader = TestConfigLoader.new
    wrapped_loader.configuration = {"qA,qB" => 1}

    throttle = Resque::Pool::ConfigThrottle.new(10, wrapped_loader, time_source: fake_time)
    first_call = throttle.call("prd")

    new_config = {"qA,qB" => 22}
    wrapped_loader.configuration = new_config
    fake_time.advance_time 6
    # the 10 second period has *not* elapsed

    throttle.reset!

    second_call = throttle.call("prd")

    second_call.should eq(new_config)
    wrapped_loader.times_called.should == 2
  end

  it "delegates reset! to the wrapped_loader, when supported" do
    wrapped_loader = TestConfigLoader.new
    throttle = Resque::Pool::ConfigThrottle.new(10, wrapped_loader)

    wrapped_loader.times_reset.should == 0
    throttle.reset!
    wrapped_loader.times_reset.should == 1
  end

  it "does not delegate reset! to the wrapped_loader when it is not supported" do
    wrapped_loader = lambda {|env| Hash.new }
    throttle = Resque::Pool::ConfigThrottle.new(10, wrapped_loader)

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
