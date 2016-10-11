# Copyright:: (c) Autotelik Media Ltd 2016
# Author ::   Tom Statter
# Date ::     Aug 2011
# License::   MIT
#
# Details::   Spree Helper for Product Loading. 
# 
#             Used to contain Utils to try to manage different Spree versions seamlessly.
#
#             But Spree now Version 3 and code base makes this pointless, anyone still on an old version
#             can just use the associated older version of this gem
#             
#             Spree Helper for RSpec testing, enables mixing in Support for
#             testing or loading Rails Spree e-commerce.
# 
#             The Spree version you want to test should be picked up from spec/Gemfile
# 
#             Since datashift gem is not a Rails app or a Spree App, provides utilities to internally
#             create a Spree Database, and to load Spree components, enabling standalone testing.
#
# =>          Has been tested with
#               0.7, 0.11.2
#               1.0.0, 1.1.2, 1.1.3
#               3-1-stable
#
require 'spree'
require 'spree_core'
    
module DataShift
    
  module SpreeEcom
        
    def self.root
      Gem.loaded_specs['spree_core'] ? Gem.loaded_specs['spree_core'].full_gem_path  : ""
    end
    
    # Helpers so we can cope with both pre 1.0 and post 1.0 versions of Spree in same datashift version

    def self.get_spree_class(x)
      if(is_namespace_version())
        MapperUtils::class_from_string("Spree::#{x}")
      else
        MapperUtils::class_from_string(x.to_s)
      end
    end

    # Return the right CLASS to attach Product images to
    # for the callers version of Spree
      
    def self.product_attachment_klazz
      @product_attachment_klazz  ||= if(DataShift::SpreeEcom::version.to_f > 1.0 )
        DataShift::SpreeEcom::get_spree_class('Variant')
      else
        DataShift::SpreeEcom::get_spree_class('Product')
      end
    end
    
    # Return the right OBJECT to attach Product images to
    # for the callers version of Spree
    
    def self.get_image_owner(record)
       record.is_a?(Spree::Product) ? record.master : record     # Owner is VARIANT
    end
    
    def self.version
      Gem.loaded_specs['spree'] ? Gem.loaded_specs['spree'].version.version : "0.0.0"
    end
    
    def self.is_namespace_version
      SpreeEcom::version.to_f >= 1
    end
  
    def self.lib_root
      File.join(root, 'lib')
    end

    def self.app_root
      File.join(root, 'app')
    end

  end
end 
