require 'spec_helper'

RSpec.configure do |config|
  config.after {
    Object.send(:remove_const, :RAILS_ENV) if defined? RAILS_ENV
    ENV.delete 'RACK_ENV'
    ENV.delete 'RAILS_ENV'
    ENV.delete 'RESQUE_ENV'
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

end
