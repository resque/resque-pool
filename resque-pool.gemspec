# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "resque/pool/version"

Gem::Specification.new do |s|
  s.name        = "resque-pool"
  s.version     = Resque::Pool::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["nicholas a. evans",]
  s.email       = ["nick@ekenosen.net"]
  s.homepage    = "http://github.com/nevans/resque-pool"
  s.summary     = "quickly and easily fork a pool of resque workers"
  s.license     = 'MIT'
  s.description = <<-EOF
    quickly and easily fork a pool of resque workers,
    saving memory (w/REE) and monitoring their uptime
  EOF

  s.add_dependency "resque",  "~> 1.22"
  s.add_dependency "trollop", "~> 2.0"
  s.add_dependency "rake"
  s.add_development_dependency "rspec",    "~> 2.10"
  s.add_development_dependency "cucumber", "~> 1.2"
  s.add_development_dependency "aruba",    "~> 0.4.11"
  s.add_development_dependency "bundler", "~> 1.0"
  s.add_development_dependency "ronn"

  # only in ruby 1.8
  s.add_development_dependency "SystemTimer" if RUBY_VERSION =~ /^1\.8/

  s.files         = %w( README.md Rakefile LICENSE.txt Changelog.md )
  s.files         += Dir.glob("lib/**/*")
  s.files         += Dir.glob("bin/**/*")
  s.files         += Dir.glob("man/**/*")
  s.files         += Dir.glob("features/**/*")
  s.files         += Dir.glob("spec/**/*")
  s.test_files    = Dir.glob("{spec,features}/**/*.{rb,yml,feature}")
  s.executables   = 'resque-pool'
  s.require_paths = ["lib"]
end
