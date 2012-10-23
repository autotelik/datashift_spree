# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Aug 2011
# License::   MIT
#
# Details::   Spree Helper for Product Loading. 
# 
#             Utils to try to manage different Spree versions seamlessly.
#             
#             Spree Helper for RSpec testing, enables mixing in Support for
#             testing or loading Rails Spree e-commerce.
# 
#             The Spree version you want to test should be picked up from spec/Gemfile
# 
#             Since datashift gem is not a Rails app or a Spree App, provides utilities to internally
#             create a Spree Database, and to load Spree components, enabling standalone testing.
#
# =>          Has been tested with  0.11.2, 0.7, 1.0.0, 1.1.2, 1.1.3
#
# =>          TODO - See if we can improve DB creation/migration ....
#             N.B Some or all of Spree Tests may fail very first time run,
#             as the database is auto generated
# =>          
require 'spree'
require 'spree_core'
    
module DataShift
    
  module SpreeHelper
        
    def self.root
      Gem.loaded_specs['spree_core'] ? Gem.loaded_specs['spree_core'].full_gem_path  : ""
    end
    
    # Helpers so we can cope with both pre 1.0 and post 1.0 versions of Spree in same datashift version

    def self.get_spree_class(x)
      if(is_namespace_version())    
        ModelMapper::class_from_string("Spree::#{x}")
      else
        ModelMapper::class_from_string(x.to_s)
      end
    end
      
    def self.get_product_class
      if(is_namespace_version())
        Object.const_get('Spree').const_get('Product')
      else
        Object.const_get('Product')
      end
    end
    
    # Return the right CLASS to attach Product images to
    # for the callers version of Spree
      
    def self.product_attachment_klazz
      @product_attachment_klazz  ||= if(DataShift::SpreeHelper::version.to_f > 1.0 )
        DataShift::SpreeHelper::get_spree_class('Variant' )
      else
        DataShift::SpreeHelper::get_spree_class('Product' )
      end
    end
    
    # Return the right OBJECT to attach Product images to
    # for the callers version of Spree
    
    def self.get_image_owner(record)
      if(SpreeHelper::version.to_f > 1) 
       record.is_a?(get_product_class) ? record.master : record     # owner is VARIANT
      else
        record.is_a?(get_product_class) ? record : record.product   # owner is PRODUCT
      end
    end
    
    def self.version
      Gem.loaded_specs['spree'] ? Gem.loaded_specs['spree'].version.version : "0.0.0"
    end
    
    def self.is_namespace_version
      SpreeHelper::version.to_f >= 1
    end
  
    def self.lib_root
      File.join(root, 'lib')
    end

    def self.app_root
      File.join(root, 'app')
    end

    def self.load()
      require 'spree'
      require 'spree_core'
    end   
  end
end 