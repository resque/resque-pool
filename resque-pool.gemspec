require_relative "lib/resque/pool/version"

Gem::Specification.new do |spec|
  spec.name        = "resque-pool"
  spec.version     = Resque::Pool::VERSION
  spec.authors     = ["nicholas a. evans",]
  spec.email       = ["nick@rubinick.dev"]

  spec.summary     = "quickly and easily fork a pool of resque workers"
  spec.description = <<-EOF
    quickly and easily fork a pool of resque workers,
    saving memory (w/REE) and monitoring their uptime
  EOF
  spec.homepage    = "http://github.com/resque/resque-pool"
  spec.license     = 'MIT'

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://github.com/resque/resque-pool"
  spec.metadata["changelog_uri"] = "https://github.com/resque/resque-pool/blob/main/Changelog.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0'

  spec.add_dependency "resque", ">= 1.22", "< 3"
  spec.add_dependency "rake",   ">= 10.0", "< 14.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "cucumber"
  spec.add_development_dependency "aruba"
  spec.add_development_dependency "ronn"
  spec.add_development_dependency "mustache"

end
