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
require "spec_helper"

require 'image_loader'

module DataShift

  describe 'SpreeImageLoading' do

    include_context 'Populate dictionary ready for Product loading'

    let (:product)  { Spree::Product.new }

    before(:each) do
      DataShift::Configuration.call.mandatory = ['sku', 'name', 'price']
    end

    it "should report errors in Image paths during CSV Product loading" do
      report_errors_tests 'SpreeProductsWithBadImages.csv'
    end

    it "should report errors in Image paths during Excel Product loading" do
      report_errors_tests 'SpreeProductsWithBadImages.xls'
    end

    def report_errors_tests( x )

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file(x))

      product_loader.run

      loader = product_loader.datashift_loader

      expect(loader.loaded_count).to eq 0
      expect(loader.failed_count).to eq 3

      expect(Spree::Product.count).to eq 0
      expect(Spree::Image.count).to eq 0

      p = Spree::Product.find_by_name("Demo Product for AR Loader")

      p.should be_nil

    end

    it "should create Image from path in Product loading column from CSV" do

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProductsWithImages.csv'))

      product_loader.run

      loader = product_loader.datashift_loader

      expect(loader.loaded_count).to eq 3
      expect(loader.failed_count).to eq 0

      expect(Spree::Image.count).to eq 3

      p = Spree::Product.find_by_name("Demo Product for AR Loader")

      expect(p.name).to eq "Demo Product for AR Loader"

      expect(p.images.size).to eq 1
      expect(p.master.images.size).to eq 1

      Spree::Product.all.each {|p| expect(p.images.size).to eq 1 }
    end

    it "should create Image from path in Product loading column from .xls"  do

      # Spreadsheet contains paths relative to here
      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProductsWithImages.xls'))

      product_loader.run

      loader = product_loader.datashift_loader

      expect(loader.loaded_count).to eq 3
      expect(loader.failed_count).to eq 0

      p = Spree::Product.find_by_name("Demo Product for AR Loader")

      expect(p.name).to eq "Demo Product for AR Loader"

      expect(p.images.size).to eq 1
      expect(p.master.images.size).to eq 1

      Spree::Product.all.each {|p| expect(p.images.size).to eq 1 }

      expect(Spree::Image.count).to eq 3
    end

    it "should create Image from path with prefix in Product loading column from Excel" do

      # Base of the fixtures path, will create a FULL path to each image
      Configuration.call.image_path_prefix = rspec_spec_path

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProductsWithImages.xls'))

      product_loader.run

      loader = product_loader.datashift_loader

      expect(loader.processed_object_count).to eq 3
      expect(loader.loaded_count).to eq 3
      expect(loader.failed_count).to eq 0

      p = Spree::Product.find_by_name("Demo Product for AR Loader")

      expect(p.name).to eq "Demo Product for AR Loader"
      expect(p.images.size).to eq 1

      Spree::Product.all.each {|p| expect(p.images.size).to eq 1 }

      expect(Spree::Image.count).to eq 3
    end

    it "should assign Images to preloaded Products by SKU via Excel"  do
      
      expect(Spree::Product.count).to eq 0

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProducts.xls'))

      product_loader.run

      expect(Spree::Image.count).to eq 0

      ["DEMO_001", "DEMO_002", "DEMO_003"].each do |sku|
        v = Spree::Variant.where( :sku => sku).first

        expect(v).to be_a Spree::Variant
        expect(v.images.size).to eq 0
      end

      Configuration.call.image_path_prefix = rspec_spec_path

      pending "This should now be a Populator"
      DataShift::SpreeEcom::ImageLoader.new.run( ifixture_file('SpreeImagesBySku.xls') )

      expect(Spree::Image.count).to eq 3

      {'DEMO_001' => 1, 'DEMO_002' => 1, 'DEMO_003' => 1}.each do |sku, count|
        expect(Spree::Variant.where( :sku => sku).first.images.size).to eq count
      end
    end

    it "should assign Images to preloaded Products by Name via Excel" do

      expect(Spree::Product.count).to eq 0

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProducts.xls'))

      product_loader.run

      loader = product_loader.datashift_loader

      expect(Spree::Image.all.size).to eq 0

      p = Spree::Product.find_by_name("Demo third row in future")

      expect(p.images.size).to eq 0

      pending "This should now be a Populator"
      loader = DataShift::SpreeEcom::ImageLoader.new

      loader.run(ifixture_file('SpreeImagesByName.xls'))

      expect(Spree::Image.all.size).to eq 4

      {'Demo Product for AR Loader' => 2, 'Demo Excel Load via Jruby' => 1, 'Demo third row in future' => 1}.each do |n, count|
        expect(Spree::Product.where(:name => n).first.images.size).to eq count
      end

      # fixtures/images/DEMO_001_ror_bag.jpeg
      # fixtures/images/DEMO_002_Powerstation.jpg
      # fixtures/images/DEMO_003_ror_mug.jpeg
    end

    it "should be able to set alternative text within images column"  do

      Configuration.call.image_path_prefix = rspec_spec_path

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProductsWithMultipleImages.xls'))

      product_loader.run

      expect(Spree::Product.count).to eq 2
      expect(Spree::Image.count).to eq  5

      p = DataShift::SpreeEcom::get_image_owner( Spree::Product.find_by_name("Demo Product 001") )

      expect(p.sku).to eq 'MULTI_001'
      expect(p.images.size).to eq 3

      expect(p.images[0].alt).to eq ''
      expect(p.images[1].alt).to eq 'alt text for multi 001'

      p = DataShift::SpreeEcom::get_image_owner( Spree::Product.find_by_name("Demo Product 002") )

      expect(p.sku).to eq 'MULTI_002'
      expect(p.images.size).to eq 2
    end


    it "should assign Images to preloaded Products from filesystem on SKU", duff: true do

      # first load some products with SKUs that match the image names
      expect(Spree::Product.count).to eq 0

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProducts.xls'))

      product_loader.run

      expect(Spree::Product.count).to eq 3
      expect(Spree::Image.all.size).to eq 0

      # now the test - find files, chew up name, find product, create image, attach

      image_klass = DataShift::SpreeEcom::get_spree_class('Image' )

      raise "Cannot find Attachment Class" unless image_klass

      owner_klass = Spree::Variant

      # TOFIX - name wont currently work for Variant and sku won't work for Product
      # so need  way to build a where clause or add scopes to Variant/Product
      attach_to_find_by_field = (owner_klass == Spree::Variant) ? :sku : :name

      attach_to_field = 'images'

      loader = DataShift::Paperclip::AttachmentLoader.new

      loader.split_file_name_on = '_'

      loader.init(owner_klass, attach_to_find_by_field, attach_to_field)

      loader.run(File.join(fixtures_path, 'images'), Spree::Image)

      expect(Spree::Image.count).to eq 3
    end
  end
end
