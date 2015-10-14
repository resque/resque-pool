require 'spec_helper'
require 'tempfile'

describe Resque::Pool::Logging do

  let(:expect_flags) { File::WRONLY | File::APPEND }
  
  # Don't pollute the log output
  before(:all) { $skip_logging = true }
  after(:all) { $skip_logging = false }

  context "when reopening logs" do

    before(:each) do
      @tmp     = Tempfile.new('')
      @fp      = File.open(@tmp.path, 'ab')
      @fp.sync = true
      @ext     = @fp.external_encoding rescue nil
      @int     = @fp.internal_encoding rescue nil
      @before  = @fp.stat.inspect
    end

    after(:each) do
      @tmp.close!
      @fp.close
    end

    it "reopens logs noop" do
      Resque::Pool::Logging.reopen_logs!.should == 0

      @before.should == File.stat(@fp.path).inspect
      @ext.should == (@fp.external_encoding rescue nil)
      @int.should == (@fp.internal_encoding rescue nil)
      expect_flags.should == (expect_flags & @fp.fcntl(Fcntl::F_GETFL))
    end

    it "reopens renamed logs" do
      tmp_path = @tmp.path.freeze
      to = Tempfile.new('')
      File.rename(tmp_path, to.path)
      File.exist?(tmp_path).should be_falsey

      Resque::Pool::Logging.reopen_logs!.should == 1

      tmp_path.should == @tmp.path
      File.exist?(tmp_path).should be_truthy
      @before.should_not == File.stat(tmp_path).inspect
      @fp.stat.inspect.should == File.stat(tmp_path).inspect
      @ext.should == (@fp.external_encoding rescue nil)
      @int.should == (@fp.internal_encoding rescue nil)
      expect_flags.should == (expect_flags & @fp.fcntl(Fcntl::F_GETFL))
      @fp.sync.should be_truthy

      to.close!
    end
  end

  context "when reopening logs with external encoding" do
    before(:each) do
      @tmp      = Tempfile.new('')
      @tmp_path = @tmp.path.dup.freeze
    end

    after(:each) do
      @tmp.close!
    end

    it "reopens logs renamed with encoding" do
      Encoding.list.each do |encoding|
        File.open(@tmp_path, "a:#{encoding.to_s}") do |fp|
          fp.sync = true
          encoding.should == fp.external_encoding
          fp.internal_encoding.should be_nil
          File.unlink(@tmp_path)
          File.exist?(@tmp_path).should be_falsey
          Resque::Pool::Logging.reopen_logs!
          
          @tmp_path.should == fp.path
          File.exist?(@tmp_path).should be_truthy
          fp.stat.inspect.should == File.stat(@tmp_path).inspect
          encoding.should == fp.external_encoding
          fp.internal_encoding.should be_nil
          expect_flags.should == (expect_flags & fp.fcntl(Fcntl::F_GETFL))
          fp.sync.should be_truthy
        end
      end
    end if STDIN.respond_to?(:external_encoding)

    # This spec can take a while to run through all of the encodings...
    it "reopens logs renamed with internal encoding", slow: true do
      Encoding.list.each do |ext|
        Encoding.list.each do |int|
          next if ext == int
          File.open(@tmp_path, "a:#{ext.to_s}:#{int.to_s}") do |fp|
            fp.sync = true
            ext.should == fp.external_encoding

            if ext != Encoding::BINARY
              int.should == fp.internal_encoding
            end

            File.unlink(@tmp_path)
            File.exist?(@tmp_path).should be_falsey
            Resque::Pool::Logging.reopen_logs!

            @tmp_path.should == fp.path
            File.exist?(@tmp_path).should be_truthy
            fp.stat.inspect.should == File.stat(@tmp_path).inspect
            ext.should == fp.external_encoding

            if ext != Encoding::BINARY
              int.should == fp.internal_encoding
            end

            expect_flags.should == (expect_flags & fp.fcntl(Fcntl::F_GETFL))
            fp.sync.should be_truthy
          end
        end
      end
    end if STDIN.respond_to?(:external_encoding)

  end

end
