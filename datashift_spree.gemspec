$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem"s version:
require 'datashift_spree/version'

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'datashift_spree'
  s.version = DataShift::SpreeEcom::VERSION
  s.authors = ['Thomas Statter']
  s.email = 'datashift@autotelik.co.uk'
  s.homepage = "http://github.com/autotelik/datashift_spree"
  s.summary = "Product and image import/export for Spree from Excel/CSV"
  s.description = "Comprehensive Excel/CSV import/export for Spree, Products,Images, any model with full associations"
  s.license     = 'MIT'

  s.required_ruby_version = '~> 2.0'

  s.files = Dir['{lib}/**/*', 'LICENSE.md', 'README.md', 'datashift_spree.thor']
  s.require_paths = ['lib']


  # leave it to datashift to define Rails versions
  s.add_runtime_dependency 'datashift'
  s.add_runtime_dependency 'mechanize', '~> 2.6', '>= 2.6.0'
  s.add_runtime_dependency 'spree', '>= 2'
end

