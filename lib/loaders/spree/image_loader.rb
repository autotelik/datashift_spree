# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Jan 2011
# License::   MIT. Free, Open Source.
#
require 'loader_base'
require 'spree_loader_base'


module DataShift

  module SpreeEcom

    # TODO - THIS CONCEPT NOW BELONGS AS A POPULATOR


    # Very specific Image Loading for existing Products in Spree. 
    #
    # Requirements : A CSV or Excel file which has 2+ columns
    # 
    #   1)  Identifies a Product via Name or SKU column
    #   2+) The full path(s) to the Images to attach to Product from column 1
    #
    class ImageLoader < SpreeLoaderBase
  
      def initialize()
        
        super()

        ModelMethods::Manager.catalog_class(Spree::Image)
        ModelMethods::Manager.catalog_class(Spree::Product)
        ModelMethods::Manager.catalog_class(Spree::Variant)

        puts "Attachment Class is #{SpreeEcom::product_attachment_klazz}" if(@verbose)
      end
      
      # Load object not an Image - need to look it up via Name or SKU
      def reset( object = nil)
        super(object)
        
        @load_object = nil
      end
      
      def run(file_name)
        super(file_name, Spree::Image)
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
          if( MethodDictionary::find_method_detail_if_column(Spree::Product, operator) )
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
