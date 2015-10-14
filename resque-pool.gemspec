require "./lib/resque/pool/version"

Gem::Specification.new do |s|
  s.name        = "resque-pool"
  s.version     = Resque::Pool::VERSION
  s.authors     = ["nicholas a. evans",]
  s.email       = ["nick@ekenosen.net"]
  s.homepage    = "http://github.com/nevans/resque-pool"
  s.summary     = "quickly and easily fork a pool of resque workers"
  s.license     = 'MIT'
  s.description = <<-EOF
    quickly and easily fork a pool of resque workers,
    saving memory (w/REE) and monitoring their uptime
  EOF

  s.required_ruby_version = '>= 2.0'

  s.add_dependency "resque", "~> 1.22"
  s.add_dependency "rake"
  s.add_development_dependency "rspec",    "~> 2.99"
  s.add_development_dependency "cucumber", "~> 1.2"
  s.add_development_dependency "aruba",    "~> 0.4.11"
  s.add_development_dependency "ronn"
  s.add_development_dependency "mustache", "~> 0.99.8" # 1.0 needs ruby 2.0

  s.files         = %w( README.md Rakefile LICENSE.txt Changelog.md )
  s.files         += Dir.glob("lib/**/*")
  s.files         += Dir.glob("bin/**/*")
  s.files         += Dir.glob("man/**/*")
  s.executables   = 'resque-pool'
end
