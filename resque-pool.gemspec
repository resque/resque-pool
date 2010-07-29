# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "resque-pool"
  s.version     = '0.0.5'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["nicholas a. evans", "Unicorn hackers"]
  s.email       = ["nick@ekenosen.net"]
  s.homepage    = "http://github.com/nevans/resque-pool"
  s.summary     = "quickly and easily fork a pool of resque workers"
  s.description = <<-EOF
    quickly and easily fork a pool of resque workers,
    saving memory (w/REE) and monitoring their uptime
  EOF

  s.required_rubygems_version = ">= 1.3.6"

  s.add_development_dependency "rspec"
  s.add_dependency "resque", "=1.9.9"

  s.files        = Dir.glob("lib/**/*") +%w[README.md]
  s.require_path = 'lib'
end
