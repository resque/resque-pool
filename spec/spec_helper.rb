require 'bundler/setup'
require 'resque/pool'

module PoolSpecHelpers
  def no_spawn(pool)
    pool.stub(:spawn_worker!) {}
    pool
  end

  def simulate_signal(pool, signal)
    pool.sig_queue.clear
    pool.sig_queue.push signal
    pool.handle_sig_queue!
  end
end
