require 'bundler/setup'
require 'resque/pool'

module PoolSpecHelpers
  def no_spawn(pool)
    allow(pool).to receive(:spawn_worker!) {}
    pool
  end

  def simulate_signal(pool, signal)
    pool.sig_queue.clear
    pool.sig_queue.push signal
    pool.handle_sig_queue!
  end
end

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

