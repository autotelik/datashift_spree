# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Jan 2011
# License::   MIT. Free, Open Source.
#
require 'loader_base'
#require 'paperclip/attachment_loader'

module DataShift

  module SpreeHelper
     
    # TODO - extract this out of SpreeHelper to create  a general paperclip loader
    class ImageLoader < SpreeBaseLoader
  
      def initialize(image = nil, options = {})
        
        opts = options.merge(:load => false)  # Don't need operators and no table Spree::Image

        super( DataShift::SpreeHelper::get_spree_class('Image'), image, opts )
        
        puts "Attachment Class is #{ImageLoader::attachment_klazz}" if(@verbose)
      end
      
      def self.attachment_klazz
        @attachment_klazz  ||= if(DataShift::SpreeHelper::version.to_f > 1.0 )
          DataShift::SpreeHelper::get_spree_class('Variant' )
        else
          DataShift::SpreeHelper::get_spree_class('Product' )
        end
        @attachment_klazz
      end
      
      def process()

        if(current_value && @current_method_detail.operator )    
          
          # find the db record to assign our Image to
          @load_object = get_record_by(@@product_klass, @current_method_detail.operator, current_value)
             
          @load_object = (SpreeHelper::version.to_f > 1) ? @load_object.master : @load_object
        
        elsif(current_value && @current_method_detail.operator?('attachment') )
         
          add_images( @load_object )  
        end
      
      end
    end      
  end
end