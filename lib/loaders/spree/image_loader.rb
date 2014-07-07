# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Jan 2011
# License::   MIT. Free, Open Source.
#
require 'loader_base'
#require 'paperclip/attachment_loader'

module DataShift

  module SpreeHelper
      
    # Very specific Image Loading for existing Products in Spree. 
    #
    # Requirements : A CSV or Excel file which has 2+ columns
    # 
    #   1)  Identifies a Product via Name or SKU column
    #   2+) The full path(s) to the Images to attach to Product from column 1
    #
    class ImageLoader < SpreeBaseLoader
  
      def initialize(image = nil, options = {})
        
        super( DataShift::SpreeHelper::get_spree_class('Image'), image, options )
         
        unless(MethodDictionary.for?(@@product_klass))
          MethodDictionary.find_operators( @@product_klass )
          MethodDictionary.build_method_details( @@product_klass )
        end
        
        unless(MethodDictionary.for?(@@variant_klass))
          MethodDictionary.find_operators( @@variant_klass )
          MethodDictionary.build_method_details( @@variant_klass )
        end
    
        puts "Attachment Class is #{SpreeHelper::product_attachment_klazz}" if(@verbose)
      end
      
      # Load object not an Image - need to look it up via Name or SKU
      def reset( object = nil)
        super(object)
        
        @load_object = nil
      end
      
      def perform_load( file_name, opts = {} )
        options = opts.dup
        
        # force inclusion means add headers to operator list even not present on Image
        options[:include_all] = true

        super(file_name, options)
      end

      def self.acceptable_path_headers
        @@path_headers ||= ['attachment', 'images', 'path']
      end
      
      # Called from associated perform_xxxx_load 
         
      # Over ride base class process with some Spree::Image specifics
      #
      # What process a value string from a column, assigning value(s) to correct association on Product.
      # Method map represents a column from a file and it's correlated Product association.
      # Value string which may contain multiple values for a collection (has_many) association.
      #
      def process(method_detail, value)  
        
        raise ImageLoadError.new("Cannot process #{value} NO details found to assign to") unless(method_detail)

        # TODO - start supporting assigning extra data via current_attribute_hash
        current_value, current_attribute_hash = @populator.prepare_data(method_detail, value)
        
        operator = method_detail.operator
                
        # TODO - current relies on correct order - i.e lookup column must come before attachment
        
        if(current_value && ImageLoader::acceptable_path_headers.include?(operator) )
         
          add_images( @load_object ) if(@load_object)
          
        elsif(current_value && method_detail.operator )    
          
          # find the db record to assign our Image usually expect either SKU (Variant) or Name (product)
          if( MethodDictionary::find_method_detail_if_column(@@product_klass, operator) )
            @load_object = get_record_by(@@product_klass, operator, current_value)
            
          elsif( MethodDictionary::find_method_detail_if_column(@@variant_klass, operator) )
            puts "Find VARIANT with  #{operator} == #{current_value}"
            @load_object = get_record_by(@@variant_klass, operator, current_value)
          else
            raise "No Spree class can be searched for by #{operator}"
          end  
          
          unless(@load_object)
            puts "WARNING: Could not find a record where #{operator} == #{current_value}"
            return
          else
            puts "Image Attachment on record #{@load_object.inspect}"
          end
             
        end
        
      end
      
    end
  end      
end