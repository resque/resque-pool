require 'resque/pool'

module Resque
  class Pool
    module Web

      VIEW_PATH = File.expand_path('web/views', File.dirname(__FILE__))
    
      def self.registered(app)

        app.get("/pools") do
          @pools = Resque::Pool.pools
          pool_view(:pools)
        end

        app.get("/pools.poll") do
        end

        app.post("/pools/:id/incr") do
          queue_list = Resque::Pool::QueueListStatus.new(params[:id], params[:queue_list])
          queue_list.incr!
          redirect url(:pools)
        end

        app.post("/pools/:id/decr") do
          queue_list = Resque::Pool::QueueListStatus.new(params[:id], params[:queue_list])
          queue_list.decr!
          redirect url(:pools)
        end

        app.post("/pools/:id/reset") do
          pool = Resque::Pool::PoolStatus.new(params[:id])
          pool.reset!
          redirect url(:pools)
        end

        app.helpers do

          def pool_view(filename, options = {}, locals = {})
            erb(File.read(File.join(::Resque::Pool::Web::VIEW_PATH, "#{filename}.erb")), options, locals)
          end

          def decr_link(pool, queue_list)
            pool_view(:update, {:layout => false}, :action => "decr", :pool => pool, :queue_list => queue_list)
          end

          def incr_link(pool, queue_list)
            pool_view(:update, {:layout => false}, :action => "incr", :pool => pool, :queue_list => queue_list)
          end

          def reset_link(pool)
            pool_view(:update, {:layout => false}, :action => "reset", :pool => pool, :queue_list => nil)
          end

        end

        app.tabs << "Pools"

      end

    end
  end
end

Resque::Server.register Resque::Pool::Web
