Gem::Specification.new do |s|
  s.name     = 'resque-durable'
  s.version  = '3.0.0'
  s.authors  = [ 'Eric Chapweske', 'Ben Osheroff' ]
  s.summary  = 'Resque queue backed by database audits, with automatic retry'
  s.homepage = 'https://github.com/zendesk/resque-durable'
  s.license  = 'MIT'
  s.files    = `git ls-files lib`.split($/)
  s.required_ruby_version = '>= 2.6'
  s.add_runtime_dependency 'activerecord', '>= 5.1'
  s.add_runtime_dependency 'resque', '~> 1.27'
  s.add_runtime_dependency 'uuidtools'
end
