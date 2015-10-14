require 'bundler/setup'
require 'bundler/gem_tasks'

# for loading the example config file in config/resque-pool.yml
require 'resque/pool/tasks'

require 'rspec/core/rake_task'

desc "Run fast RSpec code examples"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["-c", "-f progress", "--tag ~slow"]
end

desc "Run all RSpec code examples"
RSpec::Core::RakeTask.new("spec:ci") do |t|
  t.rspec_opts = ["-c", "-f progress"]
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features) do |c|
  c.profile = "rake"
end

task :default => ["spec:ci", :features]

rule(/\.[1-9]$/ => [proc { |tn| "#{tn}.ronn" }]) do |t|
  name = Resque::Pool.name.sub('::','-').upcase
  version = "%s %s" % [name, Resque::Pool::VERSION.upcase]

  manual = '--manual "%s"' % name
  organization = '--organization "%s"' % version
  sh "ronn #{manual} #{organization} <#{t.source} >#{t.name}"
end

file 'man/resque-pool.1'
file 'man/resque-pool.yml.5'
task :manpages => ['man/resque-pool.1','man/resque-pool.yml.5']
