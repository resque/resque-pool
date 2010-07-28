require 'spec'
$LOAD_PATH << File.expand_path("../lib", File.dirname(__FILE__))
require 'resque/pool'

describe "loading pool config from hash" do

  subject { Resque::Pool.new('foo' => 8, 'bar' => 43) }

  it "loads the hash into the config" do
    subject.config["foo"].should == 8
    subject.config["bar"].should == 43
  end

end
describe "loading pool config from file" do

  subject { Resque::Pool.new("spec/config1.yml") }

  it "loads the yml into the config" do
    subject.config["foo"].should == 1
    subject.config["bar"].should == 3
    subject.config["baz"].should == 2
    subject.config["foo,bar"].should == 4
  end

end
