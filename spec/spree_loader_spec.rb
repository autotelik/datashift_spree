# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Summer 2011
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for Spree aspect of datashift gem.
#
#             Provides Loaders and rake tasks specifically tailored for uploading or exporting
#             Spree Products, associations and Images
#
require File.join(File.expand_path(File.dirname(__FILE__) ), "spec_helper")

require 'product_loader'
  
describe 'SpreeLoader' do
  
  
  before(:all) do
    before_all_spree
  end

  include_context 'Populate dictionary ready for Product loading'
  
  
  it "should process a simple .xls spreadsheet" do

    @Zone_klass.delete_all

    loader = DataShift::ExcelLoader.new(@Zone_klass, true)
    
    loader.perform_load( ifixture_file('SpreeZoneExample.xls') )

    loader.loaded_count.should == @Zone_klass.count
  end

  it "should process a simple csv file" do

    @Zone_klass.delete_all

    loader = DataShift::CsvLoader.new(@Zone_klass)

    loader.perform_load( ifixture_file('SpreeZoneExample.csv') )

    loader.loaded_count.should == @Zone_klass.count
  end
  
  it "should raise an error for missing file" do
    lambda { test_basic_product('SpreeProductsSimple.txt') }.should raise_error DataShift::BadFile
  end

  it "should raise an error for unsupported file types" do
    lambda { test_basic_product('SpreeProductsDefaults.yml') }.should raise_error DataShift::UnsupportedFileType
  end
  
  # Loader should perform identically regardless of source, whether csv, .xls etc
  
  it "should load basic Products .xls via Spree loader", :fail => true do
    test_basic_product('SpreeProductsSimple.xls')
  end

  it "should load basic Products from .csv via Spree loader"  do
    test_basic_product('SpreeProductsSimple.csv')
  end

  def test_basic_product( source )
    
    @product_loader.perform_load( ifixture_file(source), :mandatory => ['sku', 'name', 'price'] )

    @Product_klass.count.should == 3
    
    # 2 products available_on set in past, 1 in future
    @Product_klass.active.size.should == 2
    @Product_klass.available.size.should == 2

    @product_loader.failed_count.should == 0
    @product_loader.loaded_count.should == 3

    @product_loader.loaded_count.should == @Product_klass.count

    p = @Product_klass.first
     
    p.sku.should == "SIMPLE_001"
    p.price.should == 345.78
    p.name.should == "Simple Product for AR Loader"
    p.description.should == "blah blah"
    p.cost_price.should == 320.00
    p.option_types.should have_exactly(1).items
    p.option_types.should have_exactly(1).items
    
    p.has_variants?.should be false
    
    if(DataShift::SpreeHelper::version.to_f < 2  )
      p.master.count_on_hand.should == 12
      DataShift::SpreeHelper::version < "1.1.3" ?  p.count_on_hand.should == 12 : p.count_on_hand.should == 0
      
       @Product_klass.last.master.count_on_hand.should == 23
    else
      puts p.master.stock_items.first.count_on_hand.should == 12
    end
     
   
  end

  
  it "should support default values for Spree Products loader" do
   
    @expected_time =  Time.now.to_s(:db) 
    
    @product_loader.populator.set_default_value('available_on', @expected_time)
    @product_loader.populator.set_default_value('cost_price', 1.0 )
    @product_loader.populator.set_default_value('meta_description', 'super duper meta desc.' )
    @product_loader.populator.set_default_value('meta_keywords', 'techno dubstep d&b' )
      

    @product_loader.populator.set_prefix('sku', 'SPEC_')
      
    test_default_values

  end

  it "should support default values from config for Spree Products loader" do
   
    @product_loader.configure_from(  ifixture_file('SpreeProductsDefaults.yml') )
    
    @product_loader.populator.set_prefix('sku', 'SPEC_')
      
    test_default_values

  end
  
  def test_default_values
    @product_loader.perform_load( ifixture_file('SpreeProductsMandatoryOnly.xls'), :mandatory => ['sku', 'name', 'price'] )
    
    @Product_klass.count.should == 3

    @product_loader.failed_count.should == 0
    @product_loader.loaded_count.should == 3
    
    p = @Product_klass.first
    
    p.sku.should == "SPEC_SIMPLE_001"
      
    @Product_klass.all { |p|
      p.sku.should.include "SPEC_"
      p.cost_price = 1.0
      p.available_on.should == @expected_time
      p.meta_description.should == 'super duper meta desc.'
      p.meta_keywords.should == 'techno dubstep d&b'
    }
  end

  ##################
  ### PROPERTIES ###
  ##################
  
  # Operation and results should be identical when loading multiple associations
  # if using either single column embedded syntax, or one column per entry.

  it "should load Products and multiple Properties from single column", :props => true do
    test_properties_creation( 'SpreeProducts.xls' )
  end

  it "should load Products and multiple Properties from multiple column", :props => true do
    test_properties_creation( 'SpreeProductsMultiColumn.xls' )
  end

  def test_properties_creation( source )

    # want to test both lookup and dynamic creation - this Prop should be found, rest created
    @Property_klass.create( :name => 'test_pp_001', :presentation => 'Test PP 001' )

    @Property_klass.count.should == 1

    @product_loader.perform_load( ifixture_file(source), :mandatory => ['sku', 'name', 'price'] )
    
    expected_multi_column_properties
  
  end
  
  def expected_multi_column_properties
    # 3 MASTER products, 11 VARIANTS
    @Product_klass.count.should == 3
    @Variant_klass.count.should == 14

    @Product_klass.first.properties.should have_exactly(1).items

    p3 = @Product_klass.all.last

    p3.properties.should have_exactly(3).items

    p3.properties.should include @Property_klass.find_by_name('test_pp_002')

    # Test the optional text value got set on assigned product property
    p3.product_properties.select {|p| p.value == 'Example free value' }.should have_exactly(1).items

  end
  
 
  
  it "should raise exception when mandatory columns missing from .xls", :ex => true do
    expect {@product_loader.perform_load(negative_fixture_file('SpreeProdMissManyMandatory.xls'), :mandatory => ['sku', 'name', 'price'] )}.to raise_error(DataShift::MissingMandatoryError)
  end
  

  it "should raise exception when single mandatory column missing from .xls", :ex => true do
    expect {@product_loader.perform_load(negative_fixture_file('SpreeProdMiss1Mandatory.xls'), :mandatory => 'sku' )}.to raise_error(DataShift::MissingMandatoryError)
  end

  it "should raise exception when mandatory columns missing from .csv", :ex => true do
    expect {@product_loader.perform_load(negative_fixture_file('SpreeProdMissManyMandatory.csv'), :mandatory => ['sku', 'name', 'price'] )}.to raise_error(DataShift::MissingMandatoryError)
  end
  

  it "should raise exception when single mandatory column missing from .csv", :ex => true do
    expect {@product_loader.perform_load(negative_fixture_file('SpreeProdMiss1Mandatory.csv'), :mandatory => 'sku' )}.to raise_error(DataShift::MissingMandatoryError)
  end

  
end