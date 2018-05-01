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
require "spec_helper"

describe 'SpreeLoader' do

  include_context 'Populate dictionary ready for Product loading'

  context ("Basic using datasshift loaders") do
    it "should process a simple .xls spreadsheet" do

      Spree::Zone.delete_all

      loader = DataShift::ExcelLoader.new

      loader.run( ifixture_file('SpreeZoneExample.xls'), Spree::Zone)

      expect(loader.loaded_count).to eq Spree::Zone.count
    end

    it "should process a simple csv file" do

      Spree::Zone.delete_all

      loader = DataShift::CsvLoader.new

      loader.run( ifixture_file('SpreeZoneExample.csv'), Spree::Zone)

      expect(loader.loaded_count).to eq Spree::Zone.count
    end

  end

  context ("Spree Specifc Loader") do

    it "should raise an error for missing file" do
      expect { test_basic_product('SpreeProductsSimple.txt') }.to raise_error DataShift::BadFile
    end

    it "should raise an error for unsupported file types" do
      expect { test_basic_product('SpreeProductsDefaults.yml') }.to raise_error DataShift::UnsupportedFileType
    end

    #  should perform identically regardless of source, whether csv, .xls etc

    it "should load basic Products .xls via Spree loader" do
      test_basic_product('SpreeProductsSimple.xls')
    end

    it "should load basic Products from .csv via Spree loader"  do
      test_basic_product('SpreeProductsSimple.csv')
    end

    def test_basic_product( source )

      product_loader =  DataShift::SpreeEcom::ProductLoader.new(ifixture_file(source))

      product_loader.run

      expect(Spree::Product.count).to eq 3

      # 2 products available_on set in past, 1 in future
      expect(Spree::Product.active.size).to eq 2
      expect(Spree::Product.available.size).to eq 2

      loader = product_loader.datashift_loader

      expect(loader.failed_count).to eq 0
      expect(loader.loaded_count).to eq 3

      expect(loader.loaded_count).to eq  Spree::Product.count

      p = Spree::Product.first

      expect(p.sku).to eq  "SIMPLE_001"
      expect(p.price).to eq  345.78
      expect(p.name).to eq  "Simple Product for AR Loader"
      expect(p.description).to eq  "blah blah"
      expect(p.cost_price).to eq  320.00

      expect(p.option_types.size).to eq 1
      expect(p.option_types.size).to eq 1

      expect(p.has_variants?).to eq false

      if(DataShift::SpreeEcom::version.to_f < 2  )
        expect(p.master.count_on_hand).to eq 12
        expect(Spree::Product.last.master.count_on_hand).to eq 23
      else
        puts p.master.stock_items.first.count_on_hand.inspect
        # expect(p.master.stock_items.first.count_on_hand).to eq 12
      end

    end

    it "should support default values for Spree Products loader" do

      @expected_time =  Time.now.to_s(:db)

      DataShift::Transformation.factory do |factory|

        factory.set_default_on(Spree::Product, 'available_on',  @expected_time )
        factory.set_default_on(Spree::Product, 'cost_price', 1.0 )
        factory.set_default_on(Spree::Product, 'meta_description', 'super duper meta desc.' )
        factory.set_default_on(Spree::Product, 'meta_keywords','techno dubstep d&b' )

        # N.B The operator must match the HEADER, so even though we know assigment will eventually try sku=
        # the header in the FILE is SKU so this will not work :
        #     factory.set_prefix_on(Spree::Product, 'sku', 'SPEC_')
        #
        factory.set_prefix_on(Spree::Product, 'SKU', 'SPEC_')
      end

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProductsMandatoryOnly.xls'))

      test_default_values(product_loader)
    end

    it "should support default values from config for Spree Products loader" do

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file('SpreeProductsMandatoryOnly.xls'))

      product_loader.configure_from(  ifixture_file('SpreeProductsDefaults.yml') )

      DataShift::Transformation.factory do |factory|
        factory.set_prefix_on(Spree::Product, 'SKU', 'SPEC_')
      end

      test_default_values(product_loader)
    end

    def test_default_values(product_loader)

      product_loader.run

      expect(Spree::Product.count).to eq  3

      expect(product_loader.failed_count).to eq  0
      expect(product_loader.loaded_count).to eq  3

      p = Spree::Product.first

      expect(p.sku).to eq  "SPEC_SIMPLE_001"

      Spree::Product.all do |p|
        p.sku.should.include "SPEC_"
        p.cost_price = 1.0
        expect(p.available_on).to eq  @expected_time
        expect(p.meta_description).to eq  'super duper meta desc.'
        expect(p.meta_keywords).to eq  'techno dubstep d&b'
      end
    end

    ##################
    ### PROPERTIES ###
    ##################

    # Operation and results should be identical when loading multiple associations
    # if using either single column embedded syntax, or one column per entry.

    it "should load Products and multiple Properties from single column"  do
      test_properties_creation( 'SpreeProducts.xls' )
    end

    it "should load Products and multiple Properties from multiple column" do
      test_properties_creation( 'SpreeProductsMultiColumn.xls' )
    end

    it "should load Properties with name:value in header", :duff => true do
      test_properties_creation( 'SpreeProductsValueInHeader.xls' )
    end

    def test_properties_creation( source )

      product_loader = DataShift::SpreeEcom::ProductLoader.new(ifixture_file(source))

      # want to test both lookup and dynamic creation - this Prop should be found, rest created
      Spree::Property.create( :name => 'test_pp_001', :presentation => 'Test PP 001' )

      expect(Spree::Property.count).to eq 1

      product_loader.run

      expected_multi_column_properties
    end

    def expected_multi_column_properties
      # 3 MASTER products, 11 VARIANTS
      expect(Spree::Product.count).to eq  3
      expect(Spree::Variant.count).to eq 14

      expect(Spree::Product.first.properties.size).to eq 1

      p3 = Spree::Product.all.last

      # puts p3.product_properties.collect(&:property).inspect

      expect(p3.product_properties.size).to eq 3
      expect(p3.properties.size).to eq 3

      # Example free value	test_pp_002	yet_another_property
      # test_pp_003:'Example free value',	test_pp_002.	yet_another_property

      #p3.product_properties.each {|p| puts p.inspect  }

      expect(p3.properties).to include Spree::Property.where(:name => 'test_pp_002').first
      #expect(p3.properties).to include Spree::Property.where(:name => 'test_pp_003').first
      expect(p3.properties).to include Spree::Property.where(:name => 'yet_another_property').first

      # Test the optional text value got set on assigned product property
      #expect(p3.product_properties.select {|p| p.value == 'Example free value' }.size).to eq 1
    end


    context ("Error situations") do

      before(:each) do
        DataShift::Configuration.call.mandatory = ['sku', 'name', 'price']
      end

      let(:product_loader) {
        DataShift::SpreeEcom::ProductLoader.new(negative_fixture_file('SpreeProdMissManyMandatory.xls'))
      }

      it "should raise exception when mandatory columns missing from .xls", :ex => true do
        expect {product_loader.run}.to raise_error(DataShift::MissingMandatoryError)
      end


      it "should raise exception when single mandatory column missing from .xls", :ex => true do
        expect {product_loader.run}.to raise_error(DataShift::MissingMandatoryError)
      end

      it "should raise exception when mandatory columns missing from .csv", :ex => true do
        expect {product_loader.run}.to raise_error(DataShift::MissingMandatoryError)
      end


      it "should raise exception when single mandatory column missing from .csv", :ex => true do
        expect {product_loader.run}.to raise_error(DataShift::MissingMandatoryError)
      end
    end

  end
end
