require 'spec/spec_helper'
require 'resque/pool'

Spec::Runner.configure do |config|
  config.before(:all) {
    RAILS_ENV = 'test'
    @config = {
      'foo' => 8,
      'test' => {
        'bar' => 10,
        'foo,bar' => 12
      },
      'development' => {
        'baz' => 14,
        'foo,bar' => 16
      }
    }
  }
end

describe Resque::Pool, "when loading the pool configuration from a Hash" do

  subject { Resque::Pool.new(@config) }

  it "should load the default values from the Hash" do
    subject.config["foo"].should == 8
  end
  
  it "should merge the values for the correct RAILS_ENV" do
    subject.config["bar"].should == 10
    subject.config["foo,bar"].should == 12
  end
  
  it "should not load the values for the 'development' RAILS_ENV" do
    subject.config["foo"].should == 8
    subject.config["bar"].should == 10
    subject.config["foo,bar"].should == 12
    subject.config["baz"].should == nil
  end
  
  it "should load the default values only when there is no RAILS_ENV" do
    Object.send(:remove_const, :RAILS_ENV)
    subject.config["foo"].should == 8
    subject.config["bar"].should == nil
    subject.config["foo,bar"].should == nil
    subject.config["baz"].should == nil
  end
  
end

describe Resque::Pool, "when loading the pool configuration from a file" do

  subject { Resque::Pool.new("spec/resque-pool.yml") }

  it "should load the default YAML" do
    subject.config["foo"].should == 1
  end
  
  it "should merge the YAML for the correct RAILS_ENV" do
    subject.config["bar"].should == 5
    subject.config["foo,bar"].should == 3
  end
  
  it "should not load the YAML for the 'development' RAILS_ENV" do
    subject.config["foo"].should == 1
    subject.config["bar"].should == 5
    subject.config["foo,bar"].should == 3
    subject.config["baz"].should == nil
  end

  it "should load the default values only when there is no RAILS_ENV" do
    Object.send(:remove_const, :RAILS_ENV)
    subject.config["foo"].should == 1
    subject.config["bar"].should == nil
    subject.config["foo,bar"].should == nil
    subject.config["baz"].should == nil
  end

end
