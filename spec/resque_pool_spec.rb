require 'spec_helper'

RSpec.configure do |config|
  config.include PoolSpecHelpers
  config.after {
    Object.send(:remove_const, :RAILS_ENV) if defined? RAILS_ENV
    ENV.delete 'RACK_ENV'
    ENV.delete 'RAILS_ENV'
    ENV.delete 'RESQUE_ENV'
    ENV.delete 'RESQUE_POOL_CONFIG'
  }
end

describe Resque::Pool, "when loading a simple pool configuration" do
  let(:config) do
    { 'foo' => 1, 'bar' => 2, 'foo,bar' => 3, 'bar,foo' => 4, }
  end
  subject { Resque::Pool.new(config) }

  context "when ENV['RACK_ENV'] is set" do
    before { ENV['RACK_ENV'] = 'development' }

    it "should load the values from the Hash" do
      subject.config["foo"].should == 1
      subject.config["bar"].should == 2
      subject.config["foo,bar"].should == 3
      subject.config["bar,foo"].should == 4
    end
  end

end

describe Resque::Pool, "when loading the pool configuration from a Hash" do

  let(:config) do
    {
      'foo' => 8,
      'test'        => { 'bar' => 10, 'foo,bar' => 12 },
      'development' => { 'baz' => 14, 'foo,bar' => 16 },
    }
  end

  subject { Resque::Pool.new(config) }

  context "when RAILS_ENV is set" do
    before { RAILS_ENV = "test" }

    it "should load the default values from the Hash" do
      subject.config["foo"].should == 8
    end

    it "should merge the values for the correct RAILS_ENV" do
      subject.config["bar"].should == 10
      subject.config["foo,bar"].should == 12
    end

    it "should not load the values for the other environments" do
      subject.config["foo,bar"].should == 12
      subject.config["baz"].should be_nil
    end

  end

  context "when Rails.env is set" do
    before(:each) do
      module Rails; end
      Rails.stub(:env).and_return('test')
    end

    it "should load the default values from the Hash" do
      subject.config["foo"].should == 8
    end

    it "should merge the values for the correct RAILS_ENV" do
      subject.config["bar"].should == 10
      subject.config["foo,bar"].should == 12
    end

    it "should not load the values for the other environments" do
      subject.config["foo,bar"].should == 12
      subject.config["baz"].should be_nil
    end

    after(:all) { Object.send(:remove_const, :Rails) }
  end


  context "when ENV['RESQUE_ENV'] is set" do
    before { ENV['RESQUE_ENV'] = 'development' }
    it "should load the config for that environment" do
      subject.config["foo"].should == 8
      subject.config["foo,bar"].should == 16
      subject.config["baz"].should == 14
      subject.config["bar"].should be_nil
    end
  end

  context "when there is no environment" do
    it "should load the default values only" do
      subject.config["foo"].should == 8
      subject.config["bar"].should be_nil
      subject.config["foo,bar"].should be_nil
      subject.config["baz"].should be_nil
    end
  end

end

describe Resque::Pool, "given no configuration" do
  subject { Resque::Pool.new(nil) }
  it "should have no worker types" do
    subject.config.should == {}
  end
end

describe Resque::Pool, "when loading the pool configuration from a file" do

  subject { Resque::Pool.new("spec/resque-pool.yml") }

  context "when RAILS_ENV is set" do
    before { RAILS_ENV = "test" }

    it "should load the default YAML" do
      subject.config["foo"].should == 1
    end

    it "should merge the YAML for the correct RAILS_ENV" do
      subject.config["bar"].should == 5
      subject.config["foo,bar"].should == 3
    end

    it "should not load the YAML for the other environments" do
      subject.config["foo"].should == 1
      subject.config["bar"].should == 5
      subject.config["foo,bar"].should == 3
      subject.config["baz"].should be_nil
    end

  end

  context "when ENV['RACK_ENV'] is set" do
    before { ENV['RACK_ENV'] = 'development' }
    it "should load the config for that environment" do
      subject.config["foo"].should == 1
      subject.config["foo,bar"].should == 4
      subject.config["baz"].should == 23
      subject.config["bar"].should be_nil
    end
  end

  context "when there is no environment" do
    it "should load the default values only" do
      subject.config["foo"].should == 1
      subject.config["bar"].should be_nil
      subject.config["foo,bar"].should be_nil
      subject.config["baz"].should be_nil
    end
  end

  context "when a custom file is specified" do
    before { ENV["RESQUE_POOL_CONFIG"] = 'spec/resque-pool-custom.yml.erb' }
    subject { Resque::Pool.new }
    it "should find the right file, and parse the ERB" do
      subject.config["foo"].should == 2
    end
  end

  context "when the file changes" do
    require 'tempfile'

    let(:config_file_path) {
      config_file = Tempfile.new("resque-pool-test")
      config_file.write "orig: 1"
      config_file.close
      config_file.path
    }

    subject {
      no_spawn(Resque::Pool.new(config_file_path))
    }

    it "should not automatically load the changes" do
      subject.config.keys.should == ["orig"]

      File.open(config_file_path, "w"){|f| f.write "changed: 1"}
      subject.config.keys.should == ["orig"]
      subject.load_config
      subject.config.keys.should == ["orig"]
    end

    it "should reload the changes on HUP signal" do
      subject.config.keys.should == ["orig"]

      File.open(config_file_path, "w"){|f| f.write "changed: 1"}
      subject.config.keys.should == ["orig"]
      subject.load_config
      subject.config.keys.should == ["orig"]

      simulate_signal subject, :HUP

      subject.config.keys.should == ["changed"]
    end

  end

end

describe Resque::Pool, "the pool configuration custom loader" do
  it "should retrieve the config based on the environment" do
    custom_loader = double(call: Hash.new)
    RAILS_ENV = "env"

    Resque::Pool.new(custom_loader)

    custom_loader.should have_received(:call).with("env")
  end

  it "should reset the config loader on HUP" do
    custom_loader = double(call: Hash.new, reset!: true)

    pool = no_spawn(Resque::Pool.new(custom_loader))
    custom_loader.should have_received(:call).once

    pool.sig_queue.push :HUP
    pool.handle_sig_queue!
    custom_loader.should have_received(:reset!)
    custom_loader.should have_received(:call).twice
  end

  it "can be a lambda" do
    RAILS_ENV = "fake"
    count = 1
    pool = no_spawn(Resque::Pool.new(lambda {|env|
      {env.reverse => count}
    }))
    pool.config.should == {"ekaf" => 1}

    count = 3
    pool.sig_queue.push :HUP
    pool.handle_sig_queue!

    pool.config.should == {"ekaf" => 3}
  end
end

describe "the class-level .config_loader attribute" do
  context "when not provided" do
    subject { Resque::Pool.create_configured }

    it "created pools use config file and hash loading logic" do
      subject.config_loader.should be_instance_of Resque::Pool::FileOrHashLoader
    end
  end

  context "when provided with a custom config loader" do
    let(:custom_config_loader) {
      double(call: Hash.new)
    }
    before(:each) { Resque::Pool.config_loader = custom_config_loader }
    after(:each) { Resque::Pool.config_loader = nil }
    subject { Resque::Pool.create_configured }

    it "created pools use the specified config loader" do
      subject.config_loader.should == custom_config_loader
    end
  end
end

describe Resque::Pool, "given after_prefork hook" do
  subject { Resque::Pool.new(nil) }

  let(:worker) { double }

  context "with a single hook" do
    before { Resque::Pool.after_prefork { @called = true } }

    it "should call prefork" do
      subject.call_after_prefork!(worker)
      @called.should == true
    end
  end

  context "with a single hook by attribute writer" do
    before { Resque::Pool.after_prefork = Proc.new { @called = true } }

    it "should call prefork" do
      subject.call_after_prefork!(worker)
      @called.should == true
    end
  end

  context "with multiple hooks" do
    before {
      Resque::Pool.after_prefork { @called_first = true }
      Resque::Pool.after_prefork { @called_second = true }
    }

    it "should call both" do
      subject.call_after_prefork!(worker)
      @called_first.should == true
      @called_second.should == true
    end
  end

  it "passes the worker instance to the hook" do
    val = nil
    Resque::Pool.after_prefork { |w| val = w }
    subject.call_after_prefork!(worker)
    val.should == worker
  end
end
