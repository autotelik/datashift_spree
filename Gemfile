source 'https://rubygems.org'

gem 'rspec'  # Behavior Driven Development (BDD) for Ruby
gem 'rspec-core'  # RSpec runner and example groups.
gem 'rspec-expectations'  # RSpec matchers for should and should_not.
gem 'rspec-mocks'  # RSpec test double framework with stubbing and mocking.
gem 'rspec-rails'  # RSpec version 2.x for Rails version 3.x.

# we want to test both JRuby and non JRuby especially for Excel

platform :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

platform :ruby do
  gem 'sqlite3'
end

group :development, :test do
  gem "debugger"
end

# DEFINE WHICH VERSIONS WE WANT TO TEST WITH

gem 'datashift'

gem 'rails', '3.2.8'
gem 'spree', '1.1.3'



