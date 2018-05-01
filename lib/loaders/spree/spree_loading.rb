# Copyright:: (c) Autotelik Media Ltd 2016
# Author ::   Tom Statter
# Date ::     Aug 2010
# License::   MIT ?
#
# Details::   Specific support for Loading Spree data
#

require 'loaders/paperclip/image_loading'

module DataShift

  module SpreeLoading

    include DataShift::ImageLoading
    include DataShift::Delimiters

    # These originally required to support early versions when Spree went from no namespace to Spree namespace

    def image_klass
      @image_klass  ||= DataShift::SpreeEcom::get_spree_class('Image')
    end

    def option_type_klass
      @option_type_klass  ||= DataShift::SpreeEcom::get_spree_class('OptionType')
    end

    def option_value_klass
      @option_value_klass  ||= DataShift::SpreeEcom::get_spree_class('OptionValue')
    end

    def property_klass
      @property_klass  ||= DataShift::SpreeEcom::get_spree_class('Property')
    end

    def product_property_klass
      @product_property_klass  ||= DataShift::SpreeEcom::get_spree_class('ProductProperty')
    end

    def stock_location_klass
      @stock_location_klass  ||= DataShift::SpreeEcom::get_spree_class('StockLocation')
    end

    def stock_movement_klass
      @stock_movement_klass  ||= DataShift::SpreeEcom::get_spree_class('StockMovement')
    end

    def taxonomy_klass
      @taxonomy_klass  ||= DataShift::SpreeEcom::get_spree_class('Taxonomy')
    end

    def taxon_klass
      @taxon_klass  ||= DataShift::SpreeEcom::get_spree_class('Taxon')
    end

    def variant_klass
      @variant_klass  ||= DataShift::SpreeEcom::get_spree_class('Variant')
    end

    # Test and code for this saved at : http://www.rubular.com/r/1de2TZsVJz

    def spree_uri_regexp
      @spree_uri_regexp ||= Regexp::new(
        '(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?'
      )
    end


    # If no owner class specified will attach Image to Spree image Owner (varies depending on version)
    #
    # Special case for Images
    #
    # A list of entries for Images.
    #
    # Multiple image items can be delimited by multi_assoc_delim
    #
    # Each item can  contain optional attributes for the Image class within {}. 
    # 
    # For example to supply the optional 'alt' text, or position for an image
    #
    #   Example => path_1{:alt => text}|path_2{:alt => more alt blah blah,
    # :position => 5}|path_3{:alt => the alt text for this path}
    #
    def add_images( record, owner = nil )

      # Spree 3 - Images stored on Variant (record.master if record is a Product)

      owner ||=  DataShift::SpreeEcom::get_image_owner(record)

      value.to_s.split(multi_assoc_delim).each do |image|

        #TODO - make this attributes_start_delim and support {alt=> 'blah, :position => 2 etc}

        if(image.match(spree_uri_regexp))

          uri, attributes = image.split(attribute_list_start)

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

          path, alt_text = image.split(name_value_delim)

          logger.debug("Processing IMAGE from PATH #{path.inspect} #{alt_text.inspect}")

          path = File.join(Configuration.call.image_path_prefix, path) if(Configuration.call.image_path_prefix)

          begin
            attachment = create_attachment(Spree::Image, path, nil, nil, :alt => alt_text)
          rescue => e
            logger.error(e.message)
            logger.error("Failed to create Image from URL #{uri}")
            raise DataShift::DataProcessingError.new("Failed to create Image from URL #{uri}")
          end

        end

        raise DataShift::DataProcessingError.new("No errors reported but failed to create Attachment") unless attachment

        begin
          owner.images << attachment
          logger.debug("Product assigned Image from : #{path.inspect}")
        rescue => e
          logger.error("Failed to assign attachment to #{owner.class} #{owner.id}")
          logger.error(e.message)
        end

      end

      record.save

    end
  end
end
