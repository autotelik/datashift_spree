# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Summer 2011
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for Spree generator aspect of datashift gem.
#
#             Provides Loaders and rake tasks specifically tailored for uploading or exporting
#             Spree Products, associations and Images
#
require File.join(File.expand_path(File.dirname(__FILE__) ), "spec_helper")

require 'excel_generator'

describe 'SpreeGenerator' do

  before(:all) do
    before_all_spree
  end

  before do
       
    before_each_spree   # inits tests, cleans DB setups model types
    
    # Create some test data
    root = @Taxonomy_klass.create( :name => 'Paintings' )
    
    if(DataShift::SpreeHelper::version.to_f > 1 )
      root.taxons.create( :name => 'Landscape' )
      root.taxons.create( :name => 'Sea' )
    else
      @Taxon_klass.create( :name => 'Landscape', :taxonomy => root )
      @Taxon_klass.create( :name => 'Sea', :taxonomy => root )
    end
  end

  it "should export any Spree model to .xls spreedsheet" do

    expected = result_file('taxonomy_export_spec.xls')

    excel = DataShift::ExcelGenerator.new(expected)

    excel.generate(@Taxonomy_klass)

    expect(File.exists?(expected)).to eq true
    
    puts "You can check results manually in file #{expected}"
    
    expected = result_file('taxon_export_spec.xls')

    excel.filename = expected

    excel.generate(@Taxon_klass)

    expect(File.exists?(expected)).to eq true
    
    puts "You can check results manually in file #{expected}"
    
  end

  it "should export Spree Product and all associations to .xls spreedsheet" do

    expected = result_file('product_and_assoc_export_spec.xls')

    excel = DataShift::ExcelGenerator.new(expected)
      
    excel.generate_with_associations(@Product_klass)

    expect(File.exists?(expected)).to eq true

    puts "You can check results manually in file #{expected}"
    
  end
    
  it "should be able to exclude single associations from template" do

    expected = result_file('product_and_assoc_export_spec.xls')

    excel = DataShift::ExcelGenerator.new(expected)
      
    excel.generate_with_associations(@Product_klass, :exclude => :has_many)

    expect(File.exists?(expected)).to eq true

    puts "You can check results manually in file #{expected}"
    
  end
  
end