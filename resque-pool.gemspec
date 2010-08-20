# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "resque-pool"
  s.version     = '0.0.8'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["nicholas a. evans",]
  s.email       = ["nick@ekenosen.net"]
  s.homepage    = "http://github.com/nevans/resque-pool"
  s.summary     = "quickly and easily fork a pool of resque workers"
  s.description = <<-EOF
    quickly and easily fork a pool of resque workers,
    saving memory (w/REE) and monitoring their uptime
  EOF

  s.required_rubygems_version = ">= 1.3.6"

  s.add_development_dependency "rspec"

  # NOTE: we must depend on an explicit version of resque until the patch at
  # http://github.com/nevans/resque (or something similar) is accepted.
  # Until then, make sure that lib/resque/pool/pooled_worker.rb stays up to
  # date with Resque::Worker#work.
  s.add_dependency "resque", "=1.9.10"

  s.files        = Dir.glob("lib/**/*") +%w[README.md]
  s.require_path = 'lib'
end
