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

  it "should report errors in Image paths during Product loading" do
    report_errors_tests 'SpreeProductsWithBadImages.csv'
    report_errors_tests 'SpreeProductsWithBadImages.xls'
  end
    
  def report_errors_tests( x )
      
    options = {:mandatory => ['sku', 'name', 'price'] }

    @product_loader.perform_load( ifixture_file(x), options )

    @product_loader.reporter.processed_object_count.should == 3
    
    @product_loader.loaded_count.should == 0
    @product_loader.failed_count.should == 3
      
    @Product_klass.count.should == 0
    @Image_klass.count.should == 0

    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.should be_nil

  end
  
  it "should create Image from path in Product loading column from CSV" do

    options = {:mandatory => ['sku', 'name', 'price'] }

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.csv'), options )

    @product_loader.loaded_count.should == 3
    @product_loader.failed_count.should == 0
    
    @Image_klass.count.should == 3

    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"

    expect(p.images.size).to eq 1
    expect(p.master.images.size).to eq 1

    @Product_klass.all.each {|p| expect(p.images.size).to eq 1 }
  end


  it "should create Image from path in Product loading column from .xls"  do

    options = {:mandatory => ['sku', 'name', 'price'] }
        
    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.xls'), options )

    @product_loader.loaded_count.should == 3
    @product_loader.failed_count.should == 0
    
    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"
    
    expect(p.images.size).to eq 1
    expect(p.master.images.size).to eq 1
    
    @Product_klass.all.each {|p| expect(p.images.size).to eq 1 }

    @Image_klass.count.should == 3
  end

  it "should create Image from path with prefix in Product loading column from Excel" do

    options = {:mandatory => ['sku', 'name', 'price'], :image_path_prefix => "#{File.expand_path(File.dirname(__FILE__))}/"}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.xls'), options )

    @product_loader.reporter.processed_object_count.should == 3
    @product_loader.loaded_count.should == 3
    @product_loader.failed_count.should == 0
    
    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"
    expect(p.images.size).to eq 1

    @Product_klass.all.each {|p| expect(p.images.size).to eq 1 }

    @Image_klass.count.should == 3
  end
  
  
  it "should create Images from urls in Product loading column from Excel" do

    options = {:mandatory => ['sku', 'name', 'price']}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImageUrls.xls'), options )

    @product_loader.reporter.processed_object_count.should == 3
    @product_loader.loaded_count.should == 3
    @product_loader.failed_count.should == 0
    
    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"
    expect(p.images.size).to eq 1
         
    
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/DEMO_001_ror_bag.jpeg
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/spree.png 
    #https://raw.github.com/autotelik/datashift_spree/master/spec/fixtures/images/DEMO_004_ror_ringer.jpeg
    #{:alt => 'third text and position', :position => 4}
 
    expected = [["image/jpeg", "DEMO_001_ror_bag"], ["image/png", 'spree'], ["image/jpeg", 'DEMO_004_ror_ringer']]
    
    @Product_klass.all.each_with_index do |p, idx| 
      expect(p.images.size).to eq 1
      i = p.images[0]
      
      i.attachment_content_type.should == expected[idx][0]
      i.attachment_file_name.should include expected[idx][1]
    end

    expect(@Image_klass.count).to eq 3
  end
  
  it "should assign Images to preloaded Products by SKU via Excel"  do

    DataShift::MethodDictionary.find_operators( @Image_klass )

    @Product_klass.count.should == 0

    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))

    @Image_klass.count.should == 0

    ["DEMO_001", "DEMO_002", "DEMO_003"].each do |sku|
      
      v = Spree::Variant.where( :sku => sku).first
      
      expect(v).to be_a Spree::Variant
      
    
      expect(v.images.size).to eq 0
    end
    
    loader = DataShift::SpreeHelper::ImageLoader.new(nil, {})

    loader.perform_load( ifixture_file('SpreeImagesBySku.xls'), {:image_path_prefix => "#{File.expand_path(File.dirname(__FILE__))}/"} )

    expect(@Image_klass.count).to eq 3

    {'DEMO_001' => 1, 'DEMO_002' => 1, 'DEMO_003' => 1}.each do |sku, count|
      expect(Spree::Variant.where( :sku => sku).first.images.size).to eq count
    end

    # fixtures/images/DEMO_001_ror_bag.jpeg
    # fixtures/images/DEMO_002_Powerstation.jpg
    # fixtures/images/DEMO_003_ror_mug.jpeg
  end

  it "should assign Images to preloaded Products by Name via Excel" do

    @Product_klass.count.should == 0

    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))

    @Image_klass.all.size.should == 0

    p = @Product_klass.find_by_name("Demo third row in future")

    expect(p.images.size).to eq 0

    loader = DataShift::SpreeHelper::ImageLoader.new(nil, {})

    loader.perform_load( ifixture_file('SpreeImagesByName.xls'), {:image_path_prefix => "#{File.expand_path(File.dirname(__FILE__))}/"} )

    @Image_klass.all.size.should == 4

    {'Demo Product for AR Loader' => 2, 'Demo Excel Load via Jruby' => 1, 'Demo third row in future' => 1}.each do |n, count|
      expect(@Product_klass.where(:name => n).first.images.size).to eq count
    end

    # fixtures/images/DEMO_001_ror_bag.jpeg
    # fixtures/images/DEMO_002_Powerstation.jpg
    # fixtures/images/DEMO_003_ror_mug.jpeg
  end

  it "should be able to set alternative text within images column", :fail=> true  do

    options = {:mandatory => ['sku', 'name', 'price'], :image_path_prefix => "#{File.expand_path(File.dirname(__FILE__))}/"}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithMultipleImages.xls'), options )

    expect(@Product_klass.count).to eq 2
    expect(@Image_klass.count).to eq  5

    p = DataShift::SpreeHelper::get_image_owner( @Product_klass.find_by_name("Demo Product 001") )

    p.sku.should == 'MULTI_001'
    expect(p.images.size).to eq 3

    p.images[0].alt.should == ''
    p.images[1].alt.should == 'alt text for multi 001'

    p = DataShift::SpreeHelper::get_image_owner( @Product_klass.find_by_name("Demo Product 002") )

    p.sku.should == 'MULTI_002'
    expect(p.images.size).to eq 2

    puts p.images.inspect
    
    #p.images.where( :attachment_file_name => "DEMO_001_ror_bag.jpeg").first1.alt.should == 'some random alt text for 002'
    #p.images.where( :attachment_file_name => ???).first.alt.should == '323X428 ror bag'

  end


  it "should assign Images to preloaded Products from filesystem on SKU" do

    # first load some products with SKUs that match the image names
    @Product_klass.count.should == 0

    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))

    @Product_klass.count.should == 3
    @Image_klass.all.size.should == 0

    # now the test - find files, chew up name, find product, create image, attach

    image_klass = DataShift::SpreeHelper::get_spree_class('Image' )

    raise "Cannot find Attachment Class" unless image_klass

    loader_options = { :verbose => true }

    owner_klass = DataShift::SpreeHelper::product_attachment_klazz

    if(DataShift::SpreeHelper::version.to_f > 1.0 )
      owner_klass.should == Spree::Variant
    else
      owner_klass.should == Spree::Product
    end

    loader_options[:attach_to_klass] = owner_klass    # Pass in real Ruby class not string class name

    # TOFIX - name wont currently work for Variant and sku won't work for Product
    # so need  way to build a where clause or add scopes to Variant/Product
    loader_options[:attach_to_find_by_field] = (owner_klass == Spree::Variant) ? :sku : :name

    loader_options[:attach_to_field] = 'images'

    loader = DataShift::Paperclip::AttachmentLoader.new(image_klass, true, nil, loader_options)

    loader.attach_to_klass.should == owner_klass

    attachment_options = { :split_file_name_on => '_' }

    loader.process_from_filesystem( File.join(fixtures_path, 'images'), attachment_options)

    @Image_klass.count.should == 3
  end
end
