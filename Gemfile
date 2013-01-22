source 'https://rubygems.org'

# This Gemfile is for TESTING really. 
# Not sure it has any use for anyone just wanting to use this gem

# DEFINE VERSIONS YOU WANT TO TEST AGAINST HERE

gem 'datashift',  :path => "../datashift"

gem 'rails', '3.2.11'
gem 'spree', '1.3.1'
gem 'mechanize'

# STATIC GEMS

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
  group :development, :test do
    gem "debugger"
  end
end