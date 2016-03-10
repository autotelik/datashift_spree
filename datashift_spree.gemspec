$LOAD_PATH.push File.expand_path('../lib', __FILE__)

require 'rake'

# Maintain your gem"s version:
require 'datashift_spree/version'

Gem::Specification.new do |s|

  s.name = 'datashift_spree'
  s.version = DataShiftSpree::VERSION
  s.authors = ['Thomas Statter']
  s.email = 'datashift@autotelik.co.uk'
  s.homepage = 'http://github.com/autotelik/datashift_spree'
  s.summary = 'Shift data between Excel/CSV and Spree'
  s.description = "Comprehensive Excel/CSV import/export for Spree, Products,Images, any model with full associations"
  s.license     = 'Open Source - MIT'

  s.required_ruby_version = '~> 2.0'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=

  s.files = Dir['{lib}/**/*', 'spec/factories/**/*', 'LICENSE', 'Rakefile', 'README.markdown', 'datashift.thor']
  s.test_files = Dir['spec/**/*']

  s.require_paths = ['lib']

  s.add_runtime_dependency 'datashift', '~> 0.16'
  s.add_runtime_dependency 'mechanize', '~> 2.6', '>= 2.6.0'

  # for the dummy rails sandbox used in testing
  s.add_development_dependency 'rubocop', '~> 0.38'
  s.add_development_dependency 'rspec', '~> 3.4'
  s.add_development_dependency 'factory_girl_rails', '~> 4.5'
  s.add_development_dependency 'database_cleaner', '~> 1.5'

end


