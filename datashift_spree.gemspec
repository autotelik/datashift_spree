$:.push File.expand_path("lib", __dir__)

# Maintain your gem"s version:
require 'datashift_spree/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "datashift_spree"
  spec.version     = DatashiftSpree::VERSION
  spec.authors     = ["Thomas Statter"]
  spec.email       = ["datashift@autotelik.eu"]
  spec.homepage    = "http://github.com/autotelik/datashift_spree"
  spec.summary     = "Product and image import/export for Spree from Excel/CSV"
  spec.description = "Comprehensive Excel/CSV import/export for Spree, Products,Images, any model with full associations"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  #spec.add_runtime_dependency 'datashift'
  #
  spec.add_runtime_dependency 'mechanize'
  spec.add_runtime_dependency 'spree', '~> 4.1.0.rc1'
  spec.add_runtime_dependency 'spree_auth_devise', '~> 4.1.0.rc1'
  spec.add_runtime_dependency 'spree_gateway', '~> 3.7'

  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rspec-rails"

end
