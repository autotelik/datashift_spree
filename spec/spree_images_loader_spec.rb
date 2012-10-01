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
require 'image_loader'

describe 'SpreeImageLoading' do
   
  include_context 'Populate dictionary ready for Product loading'
        
  before(:all) do
    before_all_spree
  end

  before(:each) do
  end


  it "should create Image from path in Product loading column from CSV" do
       
    options = {:mandatory => ['sku', 'name', 'price']}
    
    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.csv'), options )
     
    @Image_klass.all.each_with_index {|i, x| puts "SPEC CHECK IMAGE #{x}", i.inspect }
        
    p = @Product_klass.find_by_name("Demo Product for AR Loader")
    
    p.name.should == "Demo Product for AR Loader"
    
    p.images.should have_exactly(1).items
    p.master.images.should have_exactly(1).items
    
    @Product_klass.all.each {|p| p.images.should have_exactly(1).items }
    
    @Image_klass.count.should == 3
  end
  
  
  it "should create Image from path in Product loading column from Excel" do
   
    options = {:mandatory => ['sku', 'name', 'price']}
    
    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.xls'), options )
        
    p = @Product_klass.find_by_name("Demo Product for AR Loader")
    
    p.name.should == "Demo Product for AR Loader"
    p.images.should have_exactly(1).items
    
    @Product_klass.all.each {|p| p.images.should have_exactly(1).items }
     
    @Image_klass.count.should == 3

  end
  
  
  it "should be able to assign Images via Excel to preloaded Products", :fail => true  do
    
    DataShift::MethodDictionary.find_operators( @Image_klass )
    
    @Product_klass.count.should == 0
    
    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))
    
    @Image_klass.all.size.should == 0
    
    p = @Product_klass.find_by_name("Demo third row in future")
     
    p.images.should have_exactly(0).items
     
    loader = DataShift::SpreeHelper::ImageLoader.new(nil, {})
    
    loader.perform_load( ifixture_file('SpreeImages.xls'), {} )
   
    # fixtures/images/DEMO_001_ror_bag.jpeg
    # fixtures/images/DEMO_002_Powerstation.jpg
    # fixtures/images/DEMO_003_ror_mug.jpeg

    p.reload

    p.images.should have_exactly(1).items
  end
  
  it "should be able to set alternative text", :fail => true do
   
    options = {:mandatory => ['sku', 'name', 'price']}
    
    @product_loader.perform_load( ifixture_file('SpreeProductsWithMultipleImages.xls'), options )
     
    product = @Product_klass.where( :sku => 'MULTI_002').first
    
    puts product.inspect
    
    p = DataShift::SpreeHelper::get_image_owner( @Product_klass.where( :sku => 'MULTI_002') )
    
    p.name.should == "Demo Product for AR Loader"
    p.images.should have_exactly(2).items
    
    # attr_accessible :alt, :attachment, :position, :viewable_type, :viewable_id
    p.images[1].alt.should == 'some random alt text'
    
    puts p.images[1].inspect
     
    @Image_klass.count.should == 5
  end
  
end