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
   
    @Image_klass.count.should == 3
    
    #@Image_klass.all.each_with_index {|i, x| puts "SPEC CHECK IMAGE #{x}", i.inspect }
        
    p = @Product_klass.find_by_name("Demo Product for AR Loader")
    
    p.name.should == "Demo Product for AR Loader"
    
    p.images.should have_exactly(1).items
    p.master.images.should have_exactly(1).items
    
    @Product_klass.all.each {|p| p.images.should have_exactly(1).items }
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
  
  
  it "should assign Images to preloaded Products by SKU via Excel", :fail => true  do
    
    DataShift::MethodDictionary.find_operators( @Image_klass )
    
    @Product_klass.count.should == 0
    
    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))
    
    @Image_klass.count.should == 0
         
    @Product_klass.find_by_name("Demo third row in future").images.should have_exactly(0).items
     
    loader = DataShift::SpreeHelper::ImageLoader.new
    
    loader.perform_load( ifixture_file('SpreeImagesBySku.xls'), {} )
   
    @Image_klass.all.size.should == 3
    
    {'Demo Product for AR Loader' => 1, 'Demo Excel Load via Jruby' => 1, 'Demo third row in future' => 1}.each do |n, count|
      @Product_klass.where(:name => n).first.images.should have_exactly(count).items
    end
    
    # fixtures/images/DEMO_001_ror_bag.jpeg
    # fixtures/images/DEMO_002_Powerstation.jpg
    # fixtures/images/DEMO_003_ror_mug.jpeg
  end
  
  it "should assign Images to preloaded Products by Name via Excel "  do
    
    @Product_klass.count.should == 0
    
    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))
    
    @Image_klass.all.size.should == 0
    
    p = @Product_klass.find_by_name("Demo third row in future")
     
    p.images.should have_exactly(0).items
     
    loader = DataShift::SpreeHelper::ImageLoader.new
    
    loader.perform_load( ifixture_file('SpreeImagesByName.xls'), {} )
   
    @Image_klass.all.size.should == 4
    
    {'Demo Product for AR Loader' => 2, 'Demo Excel Load via Jruby' => 1, 'Demo third row in future' => 1}.each do |n, count|
      @Product_klass.where(:name => n).first.images.should have_exactly(count).items
    end
  
    # fixtures/images/DEMO_001_ror_bag.jpeg
    # fixtures/images/DEMO_002_Powerstation.jpg
    # fixtures/images/DEMO_003_ror_mug.jpeg
  end
  
  it "should be able to set alternative text" do
   
    options = {:mandatory => ['sku', 'name', 'price']}
    
    @product_loader.perform_load( ifixture_file('SpreeProductsWithMultipleImages.xls'), options )
         
    @Image_klass.count.should == 5
    
    product = @Product_klass.where(:name => "Demo Product for AR Loader").first
    
    p = DataShift::SpreeHelper::get_image_owner(product)
    
    p.sku.should == 'MULTI_001'
    p.images.should have_exactly(3).items
    
    # attr_accessible :alt, :attachment, :position, :viewable_type, :viewable_id
    p.images[1].alt.should == 'more random alt text'
         
    product = @Product_klass.where(:name => "Demo Excel Load via Jruby").first
    
    p = DataShift::SpreeHelper::get_image_owner(product)
    
    p.sku.should == 'MULTI_002'
    p.images.should have_exactly(2).items
    
    # attr_accessible :alt, :attachment, :position, :viewable_type, :viewable_id
    p.images[1].alt.should == 'some random alt text'

  end
  
end