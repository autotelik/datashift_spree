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

describe 'Spree Variants Loader' do

  before(:all) do
    before_all_spree
  end

  include_context 'Populate dictionary ready for Product loading'

  before(:each) do

    begin

      # want to test both lookup and dynamic creation - this Taxonomy should be found, rest created
      root = @Taxonomy_klass.create( :name => 'Paintings' )

      t = @Taxon_klass.new( :name => 'Landscape' )
      t.taxonomy = root
      t.save

      @Taxon_klass.count.should == 2
    rescue => e
      puts e.inspect
      puts e.backtrace
    end
  end

  # Operation and results should be identical when loading multiple associations
  # if using either single column embedded syntax, or one column per entry.

  it "should load Products and create Variants from single column" do
    test_variants_creation('SpreeProducts.xls')
  end


  it "should load Products and create Variants from multiple column #{ifixture_file('SpreeProductsMultiColumn.xls')}" do
    test_variants_creation('SpreeProductsMultiColumn.xls')
  end


  it "should load Products from multiple column csv as per .xls" do
    test_variants_creation('SpreeProductsMultiColumn.csv')
  end


  def test_variants_creation( source )
    @Product_klass.count.should == 0
    @Variant_klass.count.should == 0

    @product_loader.perform_load( ifixture_file(source), :mandatory => ['sku', 'name', 'price'] )

    expected_multi_column_variants
  end


  def expected_multi_column_variants

    # 3 MASTER products, 11 VARIANTS
    @Product_klass.count.should == 3
    @Variant_klass.count.should == 14

    p = @Product_klass.first

    p.sku.should == "DEMO_001"

    p.sku.should == "DEMO_001"
    p.price.should == 399.99
    p.description.should == "blah blah"
    p.cost_price.should == 320.00

    @Product_klass.all.select {|m| m.is_master.should == true  }


    # mime_type:jpeg mime_type:PDF mime_type:PNG

    expect(p.variants.size).to eq 3

    expect(p.option_types.size).to eq 1   # mime_type

    p.option_types[0].name.should == "mime_type"
    p.option_types[0].presentation.should == "Mime type"

    @Variant_klass.all[1].sku.should == "DEMO_001_1"
    @Variant_klass.all[1].price.should == 399.99

    # V1
    v1 = p.variants[0]

    v1.sku.should == "DEMO_001_1"
    v1.price.should == 399.99
    
    # TOFIX - update for Spree 2 - not sure how count_on_hand has morphed into stock_items
    #puts v1.stock_items.first.count_on_hand
    #puts expect(v1.stock_items.first.count_on_hand).to eq 12

    expect(v1.option_values.size).to eq 1  # mime_type: jpeg
    v1.option_values[0].name.should == "jpeg"
    v1.option_values[0].presentation.should == "Jpeg"


    v2 = p.variants[1]
    #v2.count_on_hand.should == 6
    expect(v2.option_values.size).to eq 1  # mime_type: jpeg
    v2.option_values[0].name.should == "PDF"

    v2.option_values[0].option_type.should_not be_nil
    v2.option_values[0].option_type.position.should == 0


    v3 = p.variants[2]
    #v3.count_on_hand.should == 7
    expect(v3.option_values.size).to eq 1  # mime_type: jpeg
    v3.option_values[0].name.should == "PNG"

    @Variant_klass.last.price.should == 50.34
    
    # TOFIX - update for Spree 2 - not sure how count_on_hand has morphed into stock_items
    #@Variant_klass.last.count_on_hand.should == 18

    @product_loader.failed_count.should == 0
  end

  # Composite Variant Syntax is option_type_A_name:value;option_type_B_name:value
  # which creates a SINGLE Variant with 2 option types

  it "should create Variants with MULTIPLE option types from single column in CSV", :fail => true  do
    @product_loader.perform_load( ifixture_file('SpreeMultiVariant.csv'), :mandatory => ['sku', 'name', 'price'] )

    expected_single_column_multi_variants
  end

  it "should create Variants with MULTIPLE option types from single column in XLS", :fail => true  do
    @product_loader.perform_load( ifixture_file('SpreeMultiVariant.xls'), :mandatory => ['sku', 'name', 'price'] )

    expected_single_column_multi_variants
  end
  
  def expected_single_column_multi_variants
    
    # Product 1)
    # 1 + 2) mime_type:jpeg,PDF;print_type:colour	 equivalent to (mime_type:jpeg;print_type:colour|mime_type:PDF;print_type:colour)
    # 3) mime_type:PNG
    #
    prod_count = 3
    var_count = 10

    expect(@Product_klass.count).to eq prod_count
    @Variant_klass.count.should == prod_count + var_count     # plus 3 MASTER VARIANTS

    p = @Product_klass.all[0]

    expect(p.variants_including_master.size).to eq 4
    expect(p.variants.size).to eq 3 

    expect(p.option_types.size).to eq 2  # mime_type, print_type

    v1 = p.variants[0]
    expect(v1.option_values.size).to eq 2 
    v1.option_values.collect(&:name).sort.should == ['colour','jpeg']
    v1.option_values.collect(&:presentation).sort.should == ['Colour','Jpeg']

    # Product 2
    # 4) mime_type:jpeg;print_type:black_white
    # 5) mime_type:PNG;print_type:black_white
    #
    p = @Product_klass.all[1]
    
    expect(p.variants_including_master.size).to eq 3 
    expect(p.variants.size).to eq 2

    expect( p.option_types.size).to eq 2  # mime_type, print_type

    p.option_types.collect(&:name).sort.should == ['mime_type','print_type']
    
    p.variants[0].option_values.collect(&:name).sort.should == ['black_white','jpeg']
    p.variants[0].option_values.collect(&:presentation).sort.should == ['Black white','Jpeg']
    
    p.variants[1].option_values.collect(&:name).sort.should == ['PNG', 'black_white']
    
    # Product 3
    # 6 +7) mime_type:jpeg;print_type:colour,sepia;size:large
    # 8) mime_type:jpeg;print_type:colour
    # 9) mime_type:PNG
    # 9 + 10) mime_type:PDF|print_type:black_white

        
  end



end