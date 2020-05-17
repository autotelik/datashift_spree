# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# sandbox = File.expand_path( File.join(File.dirname(__FILE__), 'dummy', 'spree_sandbox_installed.txt') )
#
# unless File.exists?(sandbox)
#
#   require File.join(File.expand_path('support', __dir__), 'sandbox_helper')
#
#   DatashiftSpree::Sandbox.install_spree
#   exit
# end

ENV['BUNDLE_GEMFILE'] = File.expand_path('dummy/Gemfile', __dir__)

require File.expand_path('dummy/config/environment', __dir__)

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.

# N.B Rails.root will be path : 'spec/dummy'

ENGINE_ROOT = File.join(File.dirname(__FILE__), '../') unless defined?  ENGINE_ROOT

Dir[File.join(File.expand_path('support', __dir__), '**', '*.rb')].each { |f| pp f; require f }

# Add additional requires below this line. Rails is not loaded until this point!

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migrator.migrations_paths = File.join(ENGINE_ROOT, 'spec/dummy/db/migrate')
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
  #
  def rspec_spree_thor_path
    @spec_thor_path ||= File.join( File.dirname(__FILE__), '..', 'lib', 'thor', 'spree')
  end

  def fixtures_path()
    File.expand_path(File.dirname(__FILE__) + '/fixtures')
  end

  def rspec_spec_path
    File.expand_path(File.dirname(__FILE__))
  end

  def ifixture_file( name )
    File.join(fixtures_path(), name)
  end

  def results_path
    File.join(fixtures_path(), 'results')
  end

  # Return location of an expected results file and ensure tree clean before test
  def result_file( name )
    expect = File.join(results_path, name)

    begin FileUtils.rm(expect); rescue; end

    expect
  end

  def results_clear
    begin FileUtils.rm_rf(results_path); rescue; end

    FileUtils.mkdir(results_path) unless File.exists?(results_path);
  end

end
