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
    #   :image_path_prefix : A common path to prefix before each image path
    #                        e,g to specifiy particular drive  {:image_path_prefix => 'C:\' }
    #
    def perform_load( file_name, opts = {} )
      @options = opts.dup

      super(file_name, @options)
    end
  
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
      owner = DataShift::SpreeHelper::get_image_owner(record)

      get_each_assoc.each do |image|

        logger.debug("Processing IMAGE from #{image.inspect}")
             
        #TODO - make this Delimiters::attributes_start_delim and support {alt=> 'blah, :position => 2 etc}

        # Test and code for this saved at : http://www.rubular.com/r/1de2TZsVJz
       
        @spree_uri_regexp ||= Regexp::new('(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?' )
        
        if(image.match(@spree_uri_regexp))
           
          uri, attributes = image.split(Delimiters::attribute_list_start)
          
          uri.strip!
          
          logger.debug("Processing IMAGE from an URI #{uri.inspect} #{attributes.inspect}")
          
          if(attributes)
            #TODO move to ColumnPacker unpack ?
            attributes = attributes.split(', ').map{|h| h1,h2 = h.split('=>'); {h1.strip! => h2.strip!}}.reduce(:merge)
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
  
          # Expected class Mechanize::Image 
  
          # there is also an method called image.extract_filename - not sure of difference
          extname = image.respond_to?(:filename) ? File.extname(image.filename) : File.extname(uri)
          base = image.respond_to?(:filename) ? File.basename(image.filename, '.*') : File.basename(uri, '.*')
          
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

            # create_attachment(klass, attachment_path, record = nil, attach_to_record_field = nil, options = {})
            attachment = create_attachment(@@image_klass, @current_image_temp_file.path, nil, nil, attributes)
            
          rescue => e
            puts "ERROR: Failed to process image from URL #{uri}", e.message
            logger.error("Failed to create Image from URL #{uri}")
            raise DataShift::DataProcessingError.new("Failed to create Image from URL #{uri}")
       
          ensure 
            @current_image_temp_file.close
            @current_image_temp_file.unlink
          end

        else     
          
          path, alt_text = image.split(Delimiters::name_value_delim)

          logger.debug("Processing IMAGE from PATH #{path.inspect} #{alt_text.inspect}")
          
          path = File.join(@options[:image_path_prefix], path) if(@options[:image_path_prefix])

          # create_attachment(klass, attachment_path, record = nil, attach_to_record_field = nil, options = {})
          attachment = create_attachment(@@image_klass, path, nil, nil, :alt => alt_text)
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