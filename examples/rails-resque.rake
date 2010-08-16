require 'resque/pool/tasks'

# this task will get called before resque:pool:setup
# preload the rails environment in the pool master
task "resque:setup" => :environment do
  # generic worker setup, e.g. Hoptoad for failed jobs
end

task "resque:pool:setup" do
  # close any sockets or files in pool master
  ActiveRecord::Base.connection.disconnect!

  # and re-open them in the resque worker parent
  Resque::Pool.after_prefork do |job|
    ActiveRecord::Base.establish_connection
  end

  # you could also re-open them in the resque worker child, using
  # Resque.after_fork, but that probably isn't necessary, and
  # Resque::Pool.after_prefork should be faster, since it won't run
  # for every single job.
end
