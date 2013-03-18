# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Summer 2011
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for Spree Image loading spect of datashift_spree gem.
#
#  NOTES
#             Some of these test will fail if not run from within spec directory since the CSV/Excel files
#             contain static paths to the image fixtures. You'll see an error like
#             
#                 Cannot process Image : Invalid Path fixtures/images/DEMO_001_ror_bag.jpeg
#             
#             These are marked with :passes_only_in_spec_dir => true do
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

  
  it "should create Images from urls in Product loading column from Excel" do

    options = {:mandatory => ['sku', 'name', 'price']}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImageUrls.xls'), options )

    @product_loader.reporter.processed_object_count.should == 3
    @product_loader.loaded_count.should == 3
    @product_loader.failed_count.should == 0
    
    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"
    p.images.should have_exactly(1).items
         
    
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/DEMO_001_ror_bag.jpeg
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/spree.png 
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/DEMO_004_ror_ringer.jpeg
    #{:alt => 'third text and position', :position => 4}
 
    expected = [["image/jpeg", "DEMO_001_ror_bag"], ["image/png", 'spree'], ["image/jpeg", 'DEMO_004_ror_ringer']]
    
    @Product_klass.all.each_with_index do |p, idx| 
      p.images.should have_exactly(1).items 
      i = p.images[0]
      
      i.attachment_content_type.should == expected[idx][0]
      i.attachment_file_name.should include expected[idx][1]
    end

    @Image_klass.count.should == 3
  end
  
  it "should handle large datasets from urls in Product loading" do

    options = {:mandatory => ['sku', 'name', 'price']}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImageUrlsLarge.xls'), options )

    @product_loader.reporter.processed_object_count.should == 300
    @product_loader.loaded_count.should == 300
    @product_loader.failed_count.should == 0
    
  
    @Image_klass.count.should == 300
  end
  


end