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
      expect(Resque::Pool::Logging.reopen_logs!).to eq(0)

      expect(@before).to eq(File.stat(@fp.path).inspect)
      expect(@ext).to eq((@fp.external_encoding rescue nil))
      expect(@int).to eq((@fp.internal_encoding rescue nil))
      expect(expect_flags).to eq((expect_flags & @fp.fcntl(Fcntl::F_GETFL)))
    end

    it "reopens renamed logs" do
      tmp_path = @tmp.path.freeze
      to = Tempfile.new('')
      File.rename(tmp_path, to.path)
      expect(File.exist?(tmp_path)).to be_falsey

      expect(Resque::Pool::Logging.reopen_logs!).to eq(1)

      expect(tmp_path).to eq(@tmp.path)
      expect(File.exist?(tmp_path)).to be_truthy
      expect(@before).to_not eq(File.stat(tmp_path).inspect)
      expect(@fp.stat.inspect).to eq(File.stat(tmp_path).inspect)
      expect(@ext).to eq((@fp.external_encoding rescue nil))
      expect(@int).to eq((@fp.internal_encoding rescue nil))
      expect(expect_flags).to eq((expect_flags & @fp.fcntl(Fcntl::F_GETFL)))
      expect(@fp.sync).to be_truthy

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
          expect(encoding).to eq(fp.external_encoding)
          expect(fp.internal_encoding).to be_nil
          File.unlink(@tmp_path)
          expect(File.exist?(@tmp_path)).to be_falsey
          Resque::Pool::Logging.reopen_logs!

          expect(@tmp_path).to eq(fp.path)
          expect(File.exist?(@tmp_path)).to be_truthy
          expect(fp.stat.inspect).to eq(File.stat(@tmp_path).inspect)
          expect(encoding).to eq(fp.external_encoding)
          expect(fp.internal_encoding).to be_nil
          expect(expect_flags).to eq((expect_flags & fp.fcntl(Fcntl::F_GETFL)))
          expect(fp.sync).to be_truthy
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
            expect(ext).to eq(fp.external_encoding)

            if ext != Encoding::BINARY
              expect(int).to eq(fp.internal_encoding)
            end

            File.unlink(@tmp_path)
            expect(File.exist?(@tmp_path)).to be_falsey
            Resque::Pool::Logging.reopen_logs!

            expect(@tmp_path).to eq(fp.path)
            expect(File.exist?(@tmp_path)).to be_truthy
            expect(fp.stat.inspect).to eq(File.stat(@tmp_path).inspect)
            expect(ext).to eq(fp.external_encoding)

            if ext != Encoding::BINARY
              expect(int).to eq(fp.internal_encoding)
            end

            expect(expect_flags).to eq((expect_flags & fp.fcntl(Fcntl::F_GETFL)))
            expect(fp.sync).to be_truthy
          end
        end
      end
    end if STDIN.respond_to?(:external_encoding)

  end

end
