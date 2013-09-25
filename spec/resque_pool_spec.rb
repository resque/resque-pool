require 'spec_helper'

RSpec.configure do |config|
  config.after {
    Object.send(:remove_const, :RAILS_ENV) if defined? RAILS_ENV
    ENV.delete 'RACK_ENV'
    ENV.delete 'RAILS_ENV'
    ENV.delete 'RESQUE_ENV'
    ENV.delete 'RESQUE_POOL_CONFIG'
  }
end

describe Resque::Pool, "when using a custom configuration manager" do
  let(:config) do
    { 'foo' => 1, 'bar' => 2, 'foo,bar' => 3, 'bar,foo' => 4, }
  end
  subject { Resque::Pool.new(config, manager) }
  before { subject.all_known_queues }

  context "when no errors are raised" do
    let(:manager) do
      lambda { |config| config.merge( "fooey" => 10 ) }
    end
    it "should merge the other values into the pool's config" do
      subject.config["fooey"].should == 10
      subject.config["foo"].should == 1
      subject.config["bar"].should == 2
      subject.config["foo,bar"].should == 3
      subject.config["bar,foo"].should == 4
    end
  end

  context "when an error is raised" do
    let(:manager) do
      lambda { |config| raise "config error was raised" }
    end

    it "should replace the config of the original on an error" do
      subject.config["foo"].should == 1
      subject.config["bar"].should == 2
      subject.config["foo,bar"].should == 3
      subject.config["bar,foo"].should == 4
    end
  end

  context "when a config override is globally set" do
    around do |e|
      Resque::Pool.config_override = lambda { |config|
        { "foo,bar,baz" => 100 }
      }
      e.run
      Resque::Pool.config_override = nil
    end
    let(:manager) { nil }

    it "should use the global configuration manager" do
      subject.config.should == { "foo,bar,baz" => 100 }
    end
  end

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
    subject { Resque::Pool.new(Resque::Pool.choose_config_file) }
    it "should find the right file, and parse the ERB" do
      subject.config["foo"].should == 2
    end
  end

end

describe Resque::Pool, "given after_prefork hook" do
  subject { Resque::Pool.new(nil) }

  context "with a single hook" do
    before { Resque::Pool.after_prefork { @called = true } }

    it "should call prefork" do
      subject.call_after_prefork!
      @called.should == true
    end
  end

  context "with a single hook by attribute writer" do
    before { Resque::Pool.after_prefork = Proc.new { @called = true } }

    it "should call prefork" do
      subject.call_after_prefork!
      @called.should == true
    end
  end

  context "with multiple hooks" do
    before {
      Resque::Pool.after_prefork { @called_first = true }
      Resque::Pool.after_prefork { @called_second = true }
    }

    it "should call both" do
      subject.call_after_prefork!
      @called_first.should == true
      @called_second.should == true
    end
  end
end
