lib = File.expand_path('../lib/', __FILE__)

$:.unshift '.' 
$:.unshift lib unless $:.include?(lib)

require 'rake'
require 'date'
require 'datashift_spree'

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = DataShift::SpreeHelper::gem_name
  s.version = DataShift::SpreeHelper::gem_version

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Thomas Statter"]
  s.date = Date.today.to_s
  s.description = "Comprehensive Excel/CSV import/export for Spree, Products,Images, any model with full associations"
  s.email = "rubygems@autotelik.co.uk"
  
  s.files = FileList["datashift_spree.thor", 
    "README.markdown",
    "datashift_spree.gemspec",
    'VERSION', 
    "LICENSE.txt", 
    "{lib}/**/*"].exclude("rdoc").exclude("nbproject").exclude("fixtures").exclude(".log").exclude(".contrib").to_a
  
  s.test_files = FileList["{spec}/*"]
  
  s.homepage = "http://github.com/autotelik/datashift_spree"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.15"
  s.summary = "Product and image import/export for Spree from Excel/CSV"
  
  s.add_dependency(%q<datashift>, [">= 0.12.0"])
  s.add_dependency(%q<mechanize>, [">= 0"])
    
  # should work with any version of spree so perhaps leave it to the client app to define
end

