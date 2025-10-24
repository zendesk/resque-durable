require_relative "lib/resque/durable/version"

Gem::Specification.new do |s|
  s.name     = "resque-durable"
  s.version  = Resque::Durable::VERSION
  s.authors  = ["Eric Chapweske", "Ben Osheroff"]
  s.summary  = "Resque queue backed by database audits, with automatic retry"
  s.homepage = "https://github.com/zendesk/resque-durable"
  s.license  = "MIT"
  s.files    = `git ls-files lib`.split($/)

  s.required_ruby_version = ">= 3.1"

  s.add_runtime_dependency("activerecord", ">= 7.0")
  s.add_runtime_dependency("resque", ">= 1.27")
  s.add_runtime_dependency("uuidtools", "~> 3.0")
  s.add_runtime_dependency("redis")
end
