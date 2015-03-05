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

require 'mechanize'

module DataShift

  class SpreeBaseLoader < LoaderBase

    include DataShift::CsvLoading
    include DataShift::ExcelLoading
    include DataShift::ImageLoading

    # depending on version get_product_class should return us right class, namespaced or not

    def initialize(klass, loader_object = nil, options = {})

      super(klass, loader_object, options)

      logger.info "Spree Loading initialised with:\n#{options.inspect}"

      #TODO - ditch this backward compatability now and just go with namespaced ?
      #
      @@image_klass ||= DataShift::SpreeEcom::get_spree_class('Image')
      @@option_type_klass ||= DataShift::SpreeEcom::get_spree_class('OptionType')
      @@option_value_klass ||= DataShift::SpreeEcom::get_spree_class('OptionValue')
      @@product_klass ||= DataShift::SpreeEcom::get_spree_class('Product')
      @@property_klass ||= DataShift::SpreeEcom::get_spree_class('Property')
      @@product_property_klass ||= DataShift::SpreeEcom::get_spree_class('ProductProperty')
      @@stock_location_klass ||= DataShift::SpreeEcom::get_spree_class('StockLocation')
      @@stock_movement_klass ||= DataShift::SpreeEcom::get_spree_class('StockMovement')
      @@taxonomy_klass ||= DataShift::SpreeEcom::get_spree_class('Taxonomy')
      @@taxon_klass ||= DataShift::SpreeEcom::get_spree_class('Taxon')
      @@variant_klass ||= DataShift::SpreeEcom::get_spree_class('Variant')

    end

    
    # Options :
    #   :image_path_prefix : A common path to prefix before each image path
    #                        e,g to specifiy particular drive  {:image_path_prefix => 'C:\' }
    #
    def perform_load( file_name, opts = {} )
      logger.info "SpreeBaseLoader - starting load from file [#{file_name}]"
      super(file_name, opts)
    end

    # TOFIX - why is this in the base class when it looks like tis Prod/Vars ?
    # either move it or make it generic so the owner can be any model that supports attachments
  
    # Special case for Images
    #
    # A list of entries for Images.
    #
    # Multiple image items can be delimited by Delimiters::multi_assoc_delim
    #
    # Each item can  contain optional attributes for the Image class within {}. 
    # 
    # For example to supply the optional 'alt' text, or position for an image
    #
    #   Example => path_1{:alt => text}|path_2{:alt => more alt blah blah, :position => 5}|path_3{:alt => the alt text for this path}
    #
    def add_images( record )

      #save_if_new

      # different versions have moved images around from Prod to Variant
      owner = DataShift::SpreeEcom::get_image_owner(record)

      #get_each_assoc.each do |image|
      # multiple files should maintain comma separated logic with 'Delimiters::multi_value_delim' and not 'Delimiters::multi_assoc_delim'
      @populator.current_value.to_s.split(Delimiters::multi_value_delim).each do |image|

        #TODO - make this Delimiters::attributes_start_delim and support {alt=> 'blah, :position => 2 etc}

        # Test and code for this saved at : http://www.rubular.com/r/1de2TZsVJz
       
        @spree_uri_regexp ||= Regexp::new('(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?' )
        
        if(image.match(@spree_uri_regexp))
           
          uri, attributes = image.split(Delimiters::attribute_list_start)
          
          uri.strip!
          
          logger.info("Processing IMAGE from URI [#{uri.inspect}]")

          if(attributes)
            #TODO move to ColumnPacker unpack ?
            attributes = attributes.split(', ').map{|h| h1,h2 = h.split('=>'); {h1.strip! => h2.strip!}}.reduce(:merge)
            logger.debug("IMAGE has additional attributes #{attributes.inspect}")
          else
            attributes = {} # will blow things up later if we pass nil where {} expected
          end
          
          agent = Mechanize.new
          
          image = begin
            agent.get(uri)
          rescue => e
            puts "ERROR: Failed to fetch image from URL #{uri}", e.message
            raise DataShift::BadUri.new("Failed to fetch image from URL #{uri}")
          end
  
          # Expected image is_a Mechanize::Image
          # image.filename& image.extract_filename do not handle query string well e,g blah.jpg?v=1234
          # so for now use URI
          # extname = image.respond_to?(:filename) ? File.extname(image.filename) : File.extname(uri)
          extname =  File.extname( uri.gsub(/\?.*=.*/, ''))

          base = image.respond_to?(:filename) ? File.basename(image.filename, '.*') : File.basename(uri, '.*')

          logger.debug("Storing Image in TempFile #{base.inspect}.#{extname.inspect}")

          @current_image_temp_file = Tempfile.new([base, extname], :encoding => 'ascii-8bit')
                    
          begin
  
            # TODO can we handle embedded img src e.g from Mechanize::Page::Image ?      

            # If I call image.save(@current_image_temp_file.path) then it creates a new file with a .1 extension
            # so the real temp file data is empty and paperclip chokes
            # so this is a copy from the Mechanize::Image save method.  don't like it much, very brittle, but what to do ...
            until image.body_io.eof? do
              @current_image_temp_file.write image.body_io.read 16384
            end           
            
            @current_image_temp_file.rewind

            logger.info("IMAGE downloaded from URI #{uri.inspect}")

            attachment = create_attachment(Spree::Image, @current_image_temp_file.path, nil, nil, attributes)
            
          rescue => e
            logger.error(e.message)
            logger.error("Failed to create Image from URL #{uri}")
            raise DataShift::DataProcessingError.new("Failed to create Image from URL #{uri}")
       
          ensure 
            @current_image_temp_file.close
            @current_image_temp_file.unlink
          end

        else     
          
          path, alt_text = image.split(Delimiters::name_value_delim)

          logger.debug("Processing IMAGE from PATH #{path.inspect} #{alt_text.inspect}")
          
          path = File.join(config[:image_path_prefix], path) if(config[:image_path_prefix])

          # create_attachment(klass, attachment_path, record = nil, attach_to_record_field = nil, options = {})
          attachment = create_attachment(Spree::Image, path, nil, nil, :alt => alt_text)
        end 

        begin
          owner.images << attachment
                    
          logger.debug("Product assigned Image from : #{path.inspect}")
        rescue => e
          puts "ERROR - Failed to assign attachment to #{owner.class} #{owner.id}"
          logger.error("Failed to assign attachment to #{owner.class} #{owner.id}")
        end

      end

      record.save

    end
  end
end