# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Summer 2011
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for Spree aspect of datashift gem.
#
#             Tests the method mapping aspect, such as that we correctly identify 
#             Spree Product attributes and associations
#             
require File.join(File.expand_path(File.dirname(__FILE__) ), "spec_helper")

  
describe 'SpreeMethodMapping' do

    
  before(:all) do
    before_all_spree
  end

  before(:each) do
   
    before_each_spree
      
    DataShift::MethodDictionary.clear
  end

  
  it "should populate operators for a Spree Product" do
  
    DataShift::MethodDictionary.find_operators( @Product_klass )
     
    DataShift::MethodDictionary.has_many.should_not be_empty
    DataShift::MethodDictionary.belongs_to.should_not be_empty
    DataShift::MethodDictionary.assignments.should_not be_empty

    assign = DataShift::MethodDictionary.assignments_for(@Product_klass)

    assign.should include('available_on')   # Example of a simple column

    DataShift::MethodDictionary.assignments[@Product_klass].should include('available_on')

    has_many_ops = DataShift::MethodDictionary.has_many_for(@Product_klass)

    has_many_ops.should include('properties')   # Product can have many properties

    DataShift::MethodDictionary.has_many[@Product_klass].should include('properties')

    btf = DataShift::MethodDictionary.belongs_to_for(@Product_klass)

    btf.should include('tax_category')    # Example of a belongs_to assignment

    DataShift::MethodDictionary.belongs_to[@Product_klass].should include('tax_category')

    expect(DataShift::MethodDictionary.column_types[@Product_klass].size).to eq @Product_klass.columns.size
  end


  it "should find method details correctly for different forms of a column name" do

    DataShift::MethodDictionary.find_operators( @Product_klass )
     
    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    ["available On", 'available_on', "Available On", "AVAILABLE_ON"].each do |format|

      method_details = DataShift::MethodDictionary.find_method_detail( @Product_klass, format )

      expect(method_details.operator).to eq 'available_on'
      expect( method_details.operator_for(:assignment)).to eq 'available_on'

      method_details.operator_for(:belongs_to).should be_nil
      method_details.operator_for(:has_many).should be_nil

      method_details.col_type.should_not be_nil
      expect( method_details.col_type.name).to eq 'available_on'
      expect(method_details.col_type.default).to eq nil
      method_details.col_type.sql_type.should include 'datetime'   # works on mysql and sqlite
      expect(method_details.col_type.type).to eq :datetime
    end
  end

  it "should populate method details correctly for has_many forms of association name" do

    DataShift::MethodDictionary.find_operators( @Product_klass )
    
    DataShift::MethodDictionary.has_many[@Product_klass].should include('product_option_types')

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    ["product_option_types", "product option types", 'product Option_types', "ProductOptionTypes", "Product_Option_Types"].each do |format|
      method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, format )

      method_detail.should_not be_nil

      method_detail.operator_for(:has_many).should eq('product_option_types')
      method_detail.operator_for(:belongs_to).should be_nil
      method_detail.operator_for(:assignment).should be_nil
    end
  end


  it "should populate method details for assignment ops (delegated columns) on #{@Product_klass}" do

    DataShift::MethodDictionary.find_operators( @Product_klass, :reload => true, :instance_methods => true )

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    # Example of delegates i.e. cost_price column on Variant, delegated to Variant by Product

    # Spree 2 .. count_on_hand replaced by StockItems 
    # mgr = DataShift::MethodDictionary.get_method_details_mgr(@Product_klass)
    # puts mgr.available_operators_with_type.inspect  
    DataShift::MethodDictionary.assignments[@Product_klass].should include('cost_currency')
    DataShift::MethodDictionary.assignments[@Product_klass].should include('cost_price')
    DataShift::MethodDictionary.assignments[@Product_klass].should include('sku')

    md = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'cost currency' )
    expect(md).to be_a DataShift::MethodDetail
    expect(md.operator).to eq 'cost_currency'

    md1 = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'Cost Price' )
    expect(md1).to be_a DataShift::MethodDetail
    expect(md1.operator).to eq 'cost_price'
    
    md2 = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'sku' )
    expect(md2).to be_a DataShift::MethodDetail
    expect(md2.operator).to eq 'sku'
  end


  it "should enable assignment via assignment ops (delegated columns) on #{@Product_klass}", :fail => true do

    DataShift::MethodDictionary.find_operators( @Product_klass, :reload => true, :instance_methods => true )

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    product = @Product_klass.new

    product.should be_new_record

    # we can use method details to populate a new AR object, essentailly same as
    # klazz_object.send( count_on_hand.operator, 2)
    
    # Spree 2 .. count_on_hand replaced by StockItems  
    price_md = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'cost_price' )

    populator = DataShift::Populator.new
      
    populator.prepare_and_assign(price_md, product, 2.23 )
    expect(product.cost_price).to eq 2.23

    
    populator.prepare_and_assign(price_md, product, 5.45 )
    expect(product.cost_price).to eq 5.45

    ["sku", "SKU", 'Sku'].each do |f|
      method = DataShift::MethodDictionary.find_method_detail( @Product_klass, f )
      method.should_not be_nil

      expect(method.operator).to eq 'sku'

      populator.prepare_and_assign(method, product, 'TEST_SK 001')
      expect(product.sku).to eq 'TEST_SK 001'
    end

  end

  
  it "should enable assignment to belongs_to association on Product", :fail =>true do

    DataShift::MethodDictionary.find_operators( @Product_klass )
    
    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'shipping_category' )

    expect(method_detail.operator).to eq 'shipping_category'

    expect(method_detail.operator_class_name).to eq 'Spree::ShippingCategory'
    expect(method_detail.operator_class).to be_a(Class)
    expect(method_detail.operator_class).to eq Spree::ShippingCategory
    
    
    method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'tax_category' )

    expect(method_detail.operator).to eq 'tax_category'

    expect(method_detail.operator_class_name).to eq 'Spree::TaxCategory'
    expect(method_detail.operator_class).to be_a(Class)
    expect(method_detail.operator_class).to eq Spree::TaxCategory
  end
    

  it "should enable assignment to has_many association on new object" do
 
    DataShift::MethodDictionary.find_operators( @Product_klass )
 
    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'taxons' )

    expect(method_detail.operator).to eq 'taxons'

    upload_object = @Product_klass.new

   expect( upload_object.taxons.size).to eq 0

    # NEW ASSOCIATION ASSIGNMENT

    # assign via the send operator directly on load object
    upload_object.send( method_detail.operator ) << @Taxon_klass.new

    expect(upload_object.taxons.size).to eq 1

    upload_object.send( method_detail.operator ) << [@Taxon_klass.new, @Taxon_klass.new]
    expect(upload_object.taxons.size).to eq 3

    # Use generic assignment on method detail - expect has_many to use << not =
    method_detail.assign( upload_object, @Taxon_klass.new )
    expect(upload_object.taxons.size).to eq 4

    method_detail.assign( upload_object, [@Taxon_klass.new, @Taxon_klass.new])
    expect(upload_object.taxons.size).to eq 6
  end

  it "should enable assignment to has_many association using existing objects" do

    DataShift::MethodDictionary.find_operators( @Product_klass )

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'product_properties' )

    method_detail.operator.to eq 'product_properties'

    klazz_object = @Product_klass.new

    pp = @ProductProperty_klass.new
    
    pp.property = @prop1

    # NEW ASSOCIATION ASSIGNMENT
    klazz_object.send( method_detail.operator ) << @ProductProperty_klass.new

    expect(klazz_object.product_properties.size).to eq 1

    klazz_object.send( method_detail.operator ) << [@ProductProperty_klass.new, @ProductProperty_klass.new]
    expect(klazz_object.product_properties.size).to eq 3

    # Use generic assignment on method detail - expect has_many to use << not =
    pp2 = @ProductProperty_klass.new
    pp2.property = @prop1
    method_detail.assign( klazz_object,  pp2)
    expect(klazz_object.product_properties.size).to eq 4

    pp3, pp4 = @ProductProperty_klass.new, @ProductProperty_klass.new
    pp3.property = @prop2
    pp4.property = @prop3
    method_detail.assign( klazz_object, [pp3, pp4])
    expect(klazz_object.product_properties.size).to eq 6

  end

  it "should leave nil entries when no method_detail found for inbound headers" do
    
    DataShift::MethodDictionary.find_operators( @Product_klass, :instance_methods => true )
 
    DataShift::MethodDictionary.build_method_details(@Product_klass)
    
    headers = ['BLAH', 'Weight', :rubbish,  :variants]
    
    method_mapper = DataShift::MethodMapper.new
     
    method_details = method_mapper.map_inbound_headers_to_methods( @Product_klass, headers )
    
    method_details.compact.should have_exactly(2).items
    
    method_details.should have_exactly(4).items
    
    method_details[0].should be_nil
    method_details[2].should be_nil
    
  end
  
  it "should add 'null' type method details for :force_inclusion items when no method_detail found" do
    
    DataShift::MethodDictionary.find_operators( @Product_klass, :instance_methods => true )
 
    DataShift::MethodDictionary.build_method_details(@Product_klass)
    
    headers = ['BLAH', 'Weight', :rubbish,  :variants]
    
    method_mapper = DataShift::MethodMapper.new
    
    options = { :force_inclusion => ['blah', :rubbish] }
   
    method_details = method_mapper.map_inbound_headers_to_methods( @Product_klass, headers, options )
    
    expect(method_details[0].name).to eq 'BLAH'
    expect(method_details[0].operator).to eq 'BLAH'
    method_details[0].col_type.should be_nil
      
    method_details.compact.should have_exactly(4).items
    
    method_details.should have_exactly(4).items
  end
    
  it "should ignore :force_inclusion items if they are genuine columns" do
    
    DataShift::MethodDictionary.find_operators( @Product_klass, :instance_methods => true )
 
    DataShift::MethodDictionary.build_method_details(@Product_klass)
    
    headers = ['VARIANTS', 'BLAH_SHOULD_BE_NULL_MD', 'Weight', :rubbish_should_be_nil]
    
    method_mapper = DataShift::MethodMapper.new
     
    options = { :force_inclusion => ['blah_SHOULD_be_null_MD', 'weight', :variants] }
   
    method_details = method_mapper.map_inbound_headers_to_methods( @Product_klass, headers, options )
    
    method_details.compact.should have_exactly(3).items
    
    method_details.should have_exactly(4).items
    
    expect(method_details[0].name).to eq 'VARIANTS' 
    expect(method_details[0].operator).to eq 'variants'
    expect(method_details[0].operator_type).to eq :has_many
    
    expect(method_details[1].name).to eq 'BLAH_SHOULD_BE_NULL_MD' 
    expect(method_details[1].operator_type).to eq :assignment
    expect(method_details[1].col_type).to be_nil
    
  end
  
  
  it "should find all method_details for instance methods based on inbound headers" do
    
    DataShift::MethodDictionary.find_operators( @Product_klass, :instance_methods => true )
 
    DataShift::MethodDictionary.build_method_details(@Product_klass)
    
    headers = ['SKU', 'Sku', :cost_price, 'PRICE', :junk, 'Weight']
    expected = ['sku', 'sku', 'cost_price', 'price', 'weight']
        
    method_mapper = DataShift::MethodMapper.new
     
    method_details = method_mapper.map_inbound_headers_to_methods( @Product_klass, headers )
    
    expect(method_details.size).to eq 6
    
    expect(method_details.compact.size).to eq 5
    
    expect(method_details.compact.collect(&:operator)).to eq expected
    
  end
  
  
   it "should find all method_details for belongs_to based on inbound headers" do
    
    DataShift::MethodDictionary.find_operators( @Product_klass, :instance_methods => true )
 
    DataShift::MethodDictionary.build_method_details(@Product_klass)
    
    headers = ['shipping category', 'shipping_category', :shippingcategory, 'Shipping_Category', 'shippingcategory']
    expected = 'shipping_category'
        
    method_mapper = DataShift::MethodMapper.new
     
    method_details = method_mapper.map_inbound_headers_to_methods( @Product_klass, headers )
    
    puts method_details.inspect
    
    expect(method_details.size).to eq 5
    
    expect(method_details.compact.size).to eq 5

    method_details.compact.collect(&:operator).each { |o| expect(o).to eq expected }
    
  end
  
end