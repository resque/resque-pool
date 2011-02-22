require 'bundler'
Bundler::GemHelper.install_tasks

# for loading the example config file in config/resque-pool.yml
require 'resque/pool/tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-c", "-f progress"]
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features) do |c|
  c.profile = "rake"
end

task :default => [:spec, :features]
