# Copyright:: (c) Autotelik B.V 2020
# Author ::   Tom Statter
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
require "rails_helper"

describe 'SpreeImageLoading' do

  include_context 'Populate dictionary ready for Product loading'

  before(:each) do
  end

  
  it "should create Images from urls in Product loading column from Excel", :fail => true do

    options = {:mandatory => ['sku', 'name', 'price']}

    product_loader.run( ifixture_file('SpreeProductsWithImageUrls.xls'), options )

    product_loader.reporter.processed_object_count.should == 3
    product_loader.loaded_count.should == 3
    product_loader.failed_count.should == 0
    
    p = Spree::Product.where(:name => "Demo Product for AR Loader").first
    
    expect(p.images.size).to eq 1

    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/DEMO_001_ror_bag.jpeg
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/spree.png 
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/DEMO_004_ror_ringer.jpeg
    #{:alt => 'third text and position', :position => 4}
 
    expected = [["image/jpeg", "DEMO_001_ror_bag"], ["image/png", 'spree'], ["image/jpeg", 'DEMO_004_ror_ringer']]
    
    Spree::Product.all.each_with_index do |p, idx|
      expect(p.images.size).to eq 1
      i = p.images[0]

      puts i.inspect
      
      #expect(i.attachment_content_type).to eq expected[idx][0]
      expect(i.attachment_file_name).to include expected[idx][1]
    end

    expect(@Image_klass.count).to eq 3
  end
  
  it "should handle large datasets from urls in Product loading" do

    options = {:mandatory => ['sku', 'name', 'price']}

    product_loader.run( ifixture_file('SpreeProductsWithImageUrlsLarge.xls'), options )

    product_loader.reporter.processed_object_count.should == 300
    product_loader.loaded_count.should == 300
    product_loader.failed_count.should == 0
    
  
    @Image_klass.count.should == 300
  end
  


end
