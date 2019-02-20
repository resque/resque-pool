require 'spec_helper'
require 'resque/pool/config_loaders/redis'

module Resque::Pool::ConfigLoaders

  describe Redis do
    before(:each) do
      Resque.redis.flushdb
      expect(Resque.redis.keys.count).to eq(0)
    end

    after(:all) do
      Resque.redis.flushdb
    end

    subject(:config) { Redis.new(environment: env) }
    subject(:env) { "prd" }

    describe "initialization" do
      it "uses default app_name and pool_name from Resque::Pool" do
        expect(Redis.new.app).to  eq(Resque::Pool.app_name)
        expect(Redis.new.pool).to eq(Resque::Pool.pool_name)
      end
      it "uses default 'unknown' environment" do
        expect(Redis.new.env).to eq("unknown")
      end
      it "uses default 'config' name" do
        expect(Redis.new.name).to eq("config")
      end
      it "constructs redis key (expecting to be namespaced under resque)" do
        config = Redis.new(app_name: "foo",
                           pool_name: "bar",
                           environment: "dev",
                           config_name: "override")
        expect(config.key).to eq("pool:config:foo:bar:dev:override")
      end
      it "uses resque's redis connection (probably namespaced)" do
        expect(Redis.new.redis).to eq(Resque.redis)
        expect(Redis.new(redis: :another).redis).to eq(:another)
      end
    end

    describe "basic API" do

      it "starts out empty" do
        expect(config.call(env)).to eq({})
      end

      it "has hash-like index setters" do
        config["foo"] = 2
        config["bar"] = 3
        config["numbers_only"] = "elephant"
        expect(config.call(env)).to eq({
          "foo" => 2,
          "bar" => 3,
          "numbers_only" => 0,
        })
      end

      it "has indifferent access (but call returns string keys)" do
        config[:foo] = 1
        config["foo"] = 2
        expect(config[:foo]).to eq(2)
        expect(config.call(env)).to eq("foo" => 2)
      end

      it "has hash-like index getters" do
        config["foo"] = 86
        config["bar"] = 99
        expect(config["foo"]).to eq(86)
        expect(config["bar"]).to eq(99)
        expect(config["nonexistent"]).to eq(0)
      end

      it "can remove keys (not just set them to zero)" do
        config["foo"] = 99
        config["bar"] = 7
        expect(config.delete("foo")).to eq(99)
        expect(config.call(env)).to eq("bar" => 7)
      end

    end

    describe "persistance" do

      it "can be loaded from another instance" do
        config["qA"] = 24
        config["qB"] = 33
        config2 = Redis.new environment: env
        expect(config2.call(env)).to eq("qA" => 24, "qB" => 33)
      end

      it "won't clash with different configs" do
        config[:foo] = 1
        config[:bar] = 2
        config2 = Redis.new app_name: "another"
        expect(config2.call(env)).to eq({})
        config3 = Redis.new pool_name: "another"
        expect(config3.call(env)).to eq({})
        config4 = Redis.new config_name: "another"
        expect(config4.call(env)).to eq({})
        config5 = Redis.new environment: "another"
        expect(config5.call(env)).to eq({})
      end

    end

  end

end
