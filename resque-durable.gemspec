Gem::Specification.new do |s|
  s.name     = "resque-durable"
  s.version  = "4.0.1"
  s.authors  = ["Eric Chapweske", "Ben Osheroff"]
  s.summary  = "Resque queue backed by database audits, with automatic retry"
  s.homepage = "https://github.com/zendesk/resque-durable"
  s.license  = "MIT"
  s.files    = `git ls-files lib`.split($/)

  s.required_ruby_version = ">= 2.6"

  s.add_runtime_dependency("activerecord", ">= 5.1")
  s.add_runtime_dependency("resque", "~> 1.27")
  s.add_runtime_dependency("uuidtools", "~> 2.2")
  s.add_runtime_dependency("redis", "< 5")

  s.add_development_dependency("bump")
  s.add_development_dependency("rake")
  s.add_development_dependency("minitest")
  s.add_development_dependency("minitest-rg")
  s.add_development_dependency("mocha")
  s.add_development_dependency("timecop")
  s.add_development_dependency("pry")
  s.add_development_dependency("sqlite3")
end
