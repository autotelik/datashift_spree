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

    options = {:mandatory => ['sku', 'name', 'price'], :image_prefix => "spec/"}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.csv'), options )

    @Image_klass.count.should == 3

    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"

    p.images.should have_exactly(1).items
    p.master.images.should have_exactly(1).items

    @Product_klass.all.each {|p| p.images.should have_exactly(1).items }
  end


  it "should create Image from path in Product loading column from Excel" do

    options = {:mandatory => ['sku', 'name', 'price'], :image_prefix => "spec/"}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.xls'), options )

    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"
    p.images.should have_exactly(1).items

    @Product_klass.all.each {|p| p.images.should have_exactly(1).items }

    @Image_klass.count.should == 3
  end

  it "should create Image from path with prefix in Product loading column from Excel" do

    options = {:mandatory => ['sku', 'name', 'price'], :image_prefix => "#{File.expand_path(File.dirname(__FILE__))}/"}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithImages.xls'), options )

    p = @Product_klass.find_by_name("Demo Product for AR Loader")

    p.name.should == "Demo Product for AR Loader"
    p.images.should have_exactly(1).items

    @Product_klass.all.each {|p| p.images.should have_exactly(1).items }

    @Image_klass.count.should == 3
  end


  it "should assign Images to preloaded Products by SKU via Excel"  do

    DataShift::MethodDictionary.find_operators( @Image_klass )

    @Product_klass.count.should == 0

    @product_loader.perform_load( ifixture_file('SpreeProducts.xls'))

    @Image_klass.count.should == 0

    @Product_klass.find_by_name("Demo third row in future").images.should have_exactly(0).items

    loader = DataShift::SpreeHelper::ImageLoader.new(nil, {})

    loader.perform_load( ifixture_file('SpreeImagesBySku.xls'), { :image_prefix => "spec/" } )

    @Image_klass.all.size.should == 3

    {'Demo Product for AR Loader' => 1, 'Demo Excel Load via Jruby' => 1, 'Demo third row in future' => 1}.each do |n, count|
      @Product_klass.where(:name => n).first.images.should have_exactly(count).items
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

    p.images.should have_exactly(0).items

    loader = DataShift::SpreeHelper::ImageLoader.new(nil, {})

    loader.perform_load( ifixture_file('SpreeImagesByName.xls'), { :image_prefix => "spec/" } )

    @Image_klass.all.size.should == 4

    {'Demo Product for AR Loader' => 2, 'Demo Excel Load via Jruby' => 1, 'Demo third row in future' => 1}.each do |n, count|
      @Product_klass.where(:name => n).first.images.should have_exactly(count).items
    end

    # fixtures/images/DEMO_001_ror_bag.jpeg
    # fixtures/images/DEMO_002_Powerstation.jpg
    # fixtures/images/DEMO_003_ror_mug.jpeg
  end

  it "should be able to set alternative text within images column" do

    options = {:mandatory => ['sku', 'name', 'price'], :image_prefix => "spec/"}

    @product_loader.perform_load( ifixture_file('SpreeProductsWithMultipleImages.xls'), options )

    @Product_klass.count.should == 2
    @Image_klass.count.should == 5

    p = DataShift::SpreeHelper::get_image_owner( @Product_klass.find_by_name("Demo Product 001") )

    p.sku.should == 'MULTI_001'
    p.images.should have_exactly(3).items

    p.images[0].alt.should == ''
    p.images[1].alt.should == 'alt text for multi 001'

    p = DataShift::SpreeHelper::get_image_owner( @Product_klass.find_by_name("Demo Product 002") )

    p.sku.should == 'MULTI_002'
    p.images.should have_exactly(2).items

    p.images[0].alt.should == 'some random alt text for 002'
    p.images[1].alt.should == '323X428 ror bag'

  end


  it "should assign Images to preloaded Products from filesystem on SKU", :fail => true  do

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