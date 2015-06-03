# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'assert_performance/version'

Gem::Specification.new do |spec|
  spec.name          = "assert_performance"
  spec.version       = AssertPerformance::VERSION
  spec.authors       = ["Kim Persson"]
  spec.email         = ["kimpersson88@gmail.com"]

  spec.summary       = %q{Benches blocks of code and saves results to provided parse database}
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]


  spec.add_runtime_dependency "parse-ruby-client", "~> 0.3.0"
  spec.add_runtime_dependency "activerecord", "~> 4.2.1"
  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2.0"
  spec.add_development_dependency "sqlite3", "~> 1.3.10"
  spec.add_development_dependency "guard", "~> 2.12.5"
  spec.add_development_dependency "guard-rspec", "~> 4.5.0"

end
