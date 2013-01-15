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

    DataShift::MethodDictionary.column_types[@Product_klass].size.should == @Product_klass.columns.size
  end


  it "should find method details correctly for different forms of a column name" do

    DataShift::MethodDictionary.find_operators( @Product_klass )
     
    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    ["available On", 'available_on', "Available On", "AVAILABLE_ON"].each do |format|

      method_details = DataShift::MethodDictionary.find_method_detail( @Product_klass, format )

      method_details.operator.should == 'available_on'
      method_details.operator_for(:assignment).should == 'available_on'

      method_details.operator_for(:belongs_to).should be_nil
      method_details.operator_for(:has_many).should be_nil

      method_details.col_type.should_not be_nil
      method_details.col_type.name.should == 'available_on'
      method_details.col_type.default.should == nil
      method_details.col_type.sql_type.should include 'datetime'   # works on mysql and sqlite
      method_details.col_type.type.should == :datetime
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


  it "should populate method details correctly for assignment operators (none columns on #{@Product_klass})" do

    DataShift::MethodDictionary.find_operators( @Product_klass, :reload => true, :instance_methods => true )

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    # Example of delegates i.e. cost_price column on Variant, delegated to Variant by Product

    DataShift::MethodDictionary.assignments[@Product_klass].should include('cost_price')
    DataShift::MethodDictionary.assignments[@Product_klass].should include('sku')


    count_on_hand = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'count on hand' )
    count_on_hand.should_not be_nil
    count_on_hand.operator.should == 'count_on_hand'

    method = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'sku' )
    method.should_not be_nil
    method.operator.should == 'sku'
  end


  it "should enable assignment via operators for none columns on #{@Product_klass}" do

    DataShift::MethodDictionary.find_operators( @Product_klass, :reload => true, :instance_methods => true )

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    klazz_object = @Product_klass.new

    klazz_object.should be_new_record

    # we can use method details to populate a new AR object, essentailly same as
    # klazz_object.send( count_on_hand.operator, 2)
    count_on_hand = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'count on hand' )

    populator = DataShift::Populator.new
      
    populator.assign(count_on_hand, klazz_object, 2 )
    klazz_object.count_on_hand.should == 2

    populator.assign(count_on_hand, klazz_object, 5 )
    klazz_object.count_on_hand.should == 5

    ["sku", "SKU", 'Sku'].each do |f|
      method = DataShift::MethodDictionary.find_method_detail( @Product_klass, f )
      method.should_not be_nil

      method.operator.should == 'sku'

      populator.assign(method, klazz_object, 'TEST_SK 001')
      klazz_object.sku.should == 'TEST_SK 001'
    end

  end

  it "should enable assignment to has_many association on new object" do
 
    DataShift::MethodDictionary.find_operators( @Product_klass )
 
    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'taxons' )

    method_detail.operator.should == 'taxons'

    upload_object = @Product_klass.new

    upload_object.taxons.size.should == 0

    # NEW ASSOCIATION ASSIGNMENT

    # assign via the send operator directly on load object
    upload_object.send( method_detail.operator ) << @Taxon_klass.new

    upload_object.taxons.size.should == 1

    upload_object.send( method_detail.operator ) << [@Taxon_klass.new, @Taxon_klass.new]
    upload_object.taxons.size.should == 3

    # Use generic assignment on method detail - expect has_many to use << not =
    method_detail.assign( upload_object, @Taxon_klass.new )
    upload_object.taxons.size.should == 4

    method_detail.assign( upload_object, [@Taxon_klass.new, @Taxon_klass.new])
    upload_object.taxons.size.should == 6
  end

  it "should enable assignment to has_many association using existing objects" do

    DataShift::MethodDictionary.find_operators( @Product_klass )

    DataShift::MethodDictionary.build_method_details( @Product_klass )
        
    method_detail = DataShift::MethodDictionary.find_method_detail( @Product_klass, 'product_properties' )

    method_detail.operator.should == 'product_properties'

    klazz_object = @Product_klass.new

    pp = @ProductProperty_klass.new
    
    pp.property = @prop1

    # NEW ASSOCIATION ASSIGNMENT
    klazz_object.send( method_detail.operator ) << @ProductProperty_klass.new

    klazz_object.product_properties.size.should == 1

    klazz_object.send( method_detail.operator ) << [@ProductProperty_klass.new, @ProductProperty_klass.new]
    klazz_object.product_properties.size.should == 3

    # Use generic assignment on method detail - expect has_many to use << not =
    pp2 = @ProductProperty_klass.new
    pp2.property = @prop1
    method_detail.assign( klazz_object,  pp2)
    klazz_object.product_properties.size.should == 4

    pp3, pp4 = @ProductProperty_klass.new, @ProductProperty_klass.new
    pp3.property = @prop2
    pp4.property = @prop3
    method_detail.assign( klazz_object, [pp3, pp4])
    klazz_object.product_properties.size.should == 6

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
    
    method_details[0].name.should == 'BLAH'
    method_details[0].operator.should == 'BLAH'
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
    
    method_details[0].name.should == 'VARIANTS' 
    method_details[0].operator.should == 'variants'
    method_details[0].operator_type.should == :has_many
    
    method_details[1].name.should == 'BLAH_SHOULD_BE_NULL_MD' 
    method_details[1].operator_type.should == :assignment
    method_details[1].col_type.should be_nil
    
  end
  
  
  it "should find all method_details for instance methods based on inbound headers" do
    
    DataShift::MethodDictionary.find_operators( @Product_klass, :instance_methods => true )
 
    DataShift::MethodDictionary.build_method_details(@Product_klass)
    
    headers = ['SKU', 'Sku', :cost_price, 'PRICE', :junk, 'Weight']
    expected = ['sku', 'sku', 'cost_price', 'price', 'weight']
        
    method_mapper = DataShift::MethodMapper.new
     
    method_details = method_mapper.map_inbound_headers_to_methods( @Product_klass, headers )
    
    method_details.should have_exactly(6).items
    
    method_details.compact.should have_exactly(5).items
    
    method_details.compact.collect(&:operator).should == expected
    
  end
  
  
end