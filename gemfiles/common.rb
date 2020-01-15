source "https://rubygems.org"
# Trigger build

gemspec :path => '..'

gem 'bump'
gem 'rake'
gem 'resque',        '~>1.25'
gem 'minitest'
gem 'minitest-rg'
gem 'mocha',         :require => 'mocha/setup'
gem 'timecop'
gem 'pry'
