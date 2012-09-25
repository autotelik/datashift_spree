# Copyright:: (c) Autotelik Media Ltd 2010
# Author ::   Tom Statter
# Date ::     Aug 2010
# License::   MIT ?
#
# Details::   Specific over-rides/additions to support Spree Products
#
require 'loader_base'

require 'csv_loader'
require 'excel_loader'
require 'image_loading'

module DataShift

  class SpreeBaseLoader < LoaderBase

    include DataShift::CsvLoading
    include DataShift::ExcelLoading
    include DataShift::ImageLoading

    # depending on version get_product_class should return us right class, namespaced or not

    def initialize(klass, loader_object = nil, options = {})
      
      super(klass, loader_object, options  )
     
      @@image_klass ||= DataShift::SpreeHelper::get_spree_class('Image')
      @@option_type_klass ||= DataShift::SpreeHelper::get_spree_class('OptionType')
      @@option_value_klass ||= DataShift::SpreeHelper::get_spree_class('OptionValue')
      @@product_klass ||= DataShift::SpreeHelper::get_spree_class('Product')
      @@property_klass ||= DataShift::SpreeHelper::get_spree_class('Property')
      @@product_property_klass ||= DataShift::SpreeHelper::get_spree_class('ProductProperty')
      @@taxonomy_klass ||= DataShift::SpreeHelper::get_spree_class('Taxonomy')
      @@taxon_klass ||= DataShift::SpreeHelper::get_spree_class('Taxon')
      @@variant_klass ||= DataShift::SpreeHelper::get_spree_class('Variant')
    end

    # Special case for Images
    # 
    # A list of entries for Images. Multiple entries delimited by Delimiters::multi_assoc_delim
    # 
    # Each entry can  with a optional 'alt' value - supplied in form :
    #  
    # => path_1:alt|path_2:alt|path_3:alt
    #
    def add_images( record )
      # TODO smart column ordering to ensure always valid by time we get to associations
      save_if_new

      image_data = get_each_assoc

      image_data.each do |image|
          
        path, alt_text = image.split(LoaderBase::name_value_delim)
   
        create_attachment(@@image_klass, path, record, :viewable, :alt => alt_text)

        logger.debug("Product assigned Image from : #{path.inspect}")
      end
      
    end
  end
end