require 'spec/spec_helper'

describe Resque::Pool::QueueListStatus do
  before do
    Resque::Pool::QueueListStatus.delete_all_keys!
  end

  subject do
    Resque::Pool::QueueListStatus.new("test.localhost:1234", "foo,bar")
  end

  context "when increasing" do
    before do
      subject.incr!
    end

    it "will not change the default count" do
      subject.default_count.should == 3
    end

    it "will increase the override count" do
      subject.override_count.should == 4
      subject.incr!
      subject.override_count.should == 5
    end

    it "will eventually change the current count"

  end

  context "when decreasing" do
    before do
      subject.decr!
    end

    it "will not change the default count" do
      subject.default_count.should == 3
    end

    it "will decrease the override count" do
      subject.override_count.should == 2
      subject.decr!
      subject.override_count.should == 1
      subject.decr!
      subject.override_count.should == 0
      subject.decr!
      subject.override_count.should == 0
    end

    it "will eventually change the current count"

  end



end
