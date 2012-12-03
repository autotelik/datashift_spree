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

    def initialize(klass, find_operators = true, loader_object = nil, options = {:instance_methods => true})

      super(klass, find_operators, loader_object, options)

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

    
    # Options :
    #   :image_prefix : A common prefix to add to each path. 
    #                   e,g to specifiy particular drive  {:image_prefix => 'C:\' }
    #
    def perform_load( file_name, opts = {} )
      @options = opts.dup

      super(file_name, @options)
    end

    # Special case for Images
    #
    # A list of entries for Images.
    #
    # Multiple entries can be delimited by Delimiters::multi_assoc_delim
    #
    # Each entry can  with a optional 'alt' value, seperated from pat5h by Delimiters::name_value_delim
    #
    #   Example => path_1:alt text|path_2:more alt blah blah|path_3:the alt text for this path
    #
    def add_images( record )

      #save_if_new

      # different versions have moved images around from Prod to Variant
      owner = DataShift::SpreeHelper::get_image_owner(record)

      get_each_assoc.each do |image|

        #TODO - make this Delimiters::attributes_start_delim and support {alt=> 'blah, :position => 2 etc}

        path, alt_text = image.split(Delimiters::name_value_delim)

        path = File.join(@options[:image_prefix], path)
          
        puts "DEBUG : Creating  attachment #{path} (#{alt_text})"
        # create_attachment(klass, attachment_path, record = nil, attach_to_record_field = nil, options = {})
        attachment = create_attachment(@@image_klass, path, nil, nil, :alt => alt_text)

        owner.images << attachment

        logger.debug("Product assigned Image from : #{path.inspect}")
      end

      record.save

    end
  end
end