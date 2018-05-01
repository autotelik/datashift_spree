# Copyright:: (c) Autotelik Media Ltd 2016
# Author ::   Tom Statter
# Date ::     2016
# License::   MIT
#
# Details::   Specific Populator for Spree Products
#
module DataShift

  module  SpreeEcom

    class ProductPopulator < Populator

      include SpreeLoading

      include DataShift::Logging
      extend DataShift::Logging

      attr_reader :product_load_object

      def prepare_and_assign_method_binding(method_binding, record, data)

        prepare_data(method_binding, data)

        @product_load_object = record

        logger.debug("Populating data via Spree specific ProductPopulator")

        logger.debug("Populating data via Spree specific ProductPopulator [#{method_binding.operator}] - [#{data}]")

        # Special cases for Products, generally where a simple one stage lookup won't suffice
        # otherwise simply use default processing from base class
        if(method_binding.operator?('variants') || method_binding.operator?('option_types'))

          add_options_variants

        elsif(method_binding.operator?('taxons'))

          add_taxons

        elsif(method_binding.operator?('product_properties')|| method_binding.operator?('properties') )

          add_properties

          # This loads images to Product or Product Master Variant depending on Spree version
        elsif(method_binding.operator?('images') || method_binding.operator?('Images'))

          add_images( product_load_object.master )

          # This loads images to Product Variants
        elsif(method_binding.operator?('variant_images'))

          add_variant_images(data)

        elsif(method_binding.operator?('variant_price') && product_load_object.variants.size > 0)

          if(data.to_s.include?(multi_assoc_delim))

            # Check if we processed Option Types and assign  per option
            values = data.to_s.split(multi_assoc_delim)

            if(record.variants.size == values.size)
              record.variants.each_with_index {|v, i| v.price = values[i].to_f }
              record.save
            else
              puts "WARNING: Price entries did not match number of Variants - None Set"
            end
          end

        elsif(method_binding.operator?('variant_cost_price') && product_load_object.variants.size > 0)

          if(data.to_s.include?(multi_assoc_delim))

            # Check if we processed Option Types and assign  per option
            values = data.to_s.split(multi_assoc_delim)

            if(product_load_object.variants.size == values.size)
              product_load_object.variants.each_with_index {|v, i| v.cost_price = values[i].to_f }
              product_load_object.save
            else
              puts "WARNING: Cost Price entries did not match number of Variants - None Set"
            end
          end

        elsif(method_binding.operator?('variant_sku') && product_load_object.variants.size > 0)

          if(data.to_s.include?(multi_assoc_delim))

            # Check if we processed Option Types and assign  per option
            values = data.to_s.split(multi_assoc_delim)

            if(product_load_object.variants.size == values.size)
              product_load_object.variants.each_with_index {|v, i| v.sku = values[i].to_s }
              product_load_object.save
            else
              puts "WARNING: SKU entries did not match number of Variants - None Set"
            end
          end

        elsif(data && method_binding.operator?('stock_items'))

          logger.info "Adding Variants Stock Items (count_on_hand)"

          product_load_object.save_if_new

          add_variants_stock(data)

        else
          super(method_binding, product_load_object, data) if(data)
        end

      end

      private

      # Special case for OptionTypes as it's two stage process
      # First add the possible option_types to Product, then we are able
      # to define Variants on those options values.
      # So to define a Variant :
      #   1) define at least one OptionType on Product, for example Size
      #   2) Provide a value for at least one of these OptionType
      #   3) A composite Variant can be created by supplying a value for more than one OptionType
      #       fro example Colour : Red and Size Medium
      #
      # Supported Syntax :
      #  '|' seperates Variants
      #
      #   ';' list of option values
      #  Examples :
      #
      #     mime_type:jpeg;print_type:black_white|mime_type:jpeg|mime_type:png, PDF;print_type:colour
      #
      def build_option_types(option_types)

        optiontype_vlist_map = {}

        option_types.each do |ostr|

          oname, value_str = ostr.split(name_value_delim)

          option_type = option_type_klass.where(:name => oname).first

          unless option_type
            option_type = option_type_klass.create(:name => oname, :presentation => oname.humanize)

            unless option_type
              logger.warm("WARNING: OptionType #{oname} NOT found and could not create - Not set Product")
              next
            end
            logger.info "Created missing OptionType #{option_type.inspect}"
          end

          # OptionTypes must be specified first on Product to enable Variants to be created
          product_load_object.option_types << option_type unless product_load_object.option_types.include?(option_type)

          # Can be simply list of OptionTypes, some or all without values
          next unless(value_str)

          optiontype_vlist_map[option_type] ||= []

          # Now get the value(s) for the option e.g red,blue,green for OptType 'colour'
          optiontype_vlist_map[option_type] += value_str.split(',').flatten
        end


        # A single Variant can have MULTIPLE Option Types and the Syntax supports this combining
        #
        # So we need the LONGEST set of OptionValues - to use as the BASE for combining with the rest
        #
        #   mime_type:png,PDF; print_type:colour
        #
        # This means create 2 Variants
        #     1 mime_type:png && print_type:colour
        #     1 mime_type:PDF && print_type:colour
        #
        # And we want to identify this "mime_type:png,PDF" as the longest to combine with the smaller print_type list

        sorted_map = optiontype_vlist_map.sort_by { |ot, ov| ov.size }.reverse

        sorted_map

      end

      def add_options_variants

        # TODO smart column ordering to ensure always valid by time we get to associations
        begin
          product_load_object.save_if_new
        rescue => e
          logger.error("Cannot add OptionTypes/Variants - Save Failed : #{e.inspect}")
          raise ProductLoadError.new("Cannot add OptionTypes/Variants - Save failed on parent Product")
        end

        # Split into multiple Variants - '|' seperates
        #
        # So  mime_type:jpeg | print_type:black_white
        #
        #     => 2 Variants on different OpTypes, mime_type and print_type
        #
        variant_chain =  value.to_s.split( multi_assoc_delim )

        variant_chain.each do |per_variant|

          option_types = per_variant.split(multi_facet_delim)    # => [mime_type:jpeg, print_type:black_white]

          logger.info "Building Variants based on Option Types #{option_types.inspect}"

          sorted_map = build_option_types(option_types)

          next if(sorted_map.empty?) # Only option types specified - no values, so no Variant to create

          # {mime => ['pdf', 'jpeg', 'gif'], print_type => ['black_white']}

          lead_option_type, lead_ovalues = sorted_map.shift

          # TODO .. benchmarking to find most efficient way to create these but ensure Product.variants list
          # populated .. currently need to call reload to ensure this (seems reqd for Spree 1/Rails 3, wasn't required b4
          lead_ovalues.each do |ovname|

            ov_list = []

            ovname.strip!

            logger.info("Adding Variant for #{ovname} on #{lead_option_type}")

            # TODO - not sure why I create the OptionValues here, rather than above with the OptionTypes
            ov = option_value_klass.where(:name => ovname,
                                          :option_type_id => lead_option_type.id).first_or_create(:presentation => ovname.humanize)
            ov_list << ov if ov

            # Process rest of array of types => values
            sorted_map.each do |ot, ovlist|
              ovlist.each do |ov_for_composite|

                ov_for_composite.strip!

                ov = option_value_klass.where(
                  :name => ov_for_composite,
                  :option_type_id => ot.id).first_or_create(:presentation => ov_for_composite.humanize)

                ov_list << ov if(ov)
              end
            end

            unless(ov_list.empty?)

              logger.info("Creating Variant on OptionValue(s) #{ov_list.collect(&:name).inspect}")

              i = product_load_object.variants.size + 1

              product_load_object.variants.create!(
                :sku => "#{product_load_object.sku}_#{i}",
                :price => product_load_object.price,
                :weight => product_load_object.weight,
                :height => product_load_object.height,
                :width => product_load_object.width,
                :depth => product_load_object.depth,
                :tax_category_id => product_load_object.tax_category_id,
                :option_values => ov_list
              )

            end
          end

        end

      end # each Variant

      # Special case for ProductProperties since it can have additional value applied.
      # A list of Properties with a optional Value - supplied in form :
      #   property_name:value|property_name|property_name:value
      #  Example :
      #  test_pp_002|test_pp_003:Example free value

      def add_properties
        # TODO smart column ordering to ensure always valid by time we get to associations
        product_load_object.save_if_new

        property_list = value.to_s.split(multi_assoc_delim)

        property_list.each do |property_string|

          # Special case, we know we lookup on name so operator is effectively the name to lookup

          # split into usable parts ; size:large or colour:red,green,blue
          find_by_name, find_by_value = property_string.split(name_value_delim)

          raise "Cannot find Property via #{find_by_name} (with value #{find_by_value})" unless(find_by_name)

          property = Spree::Property.where(:name => find_by_name).first

          unless property
            property = property_klass.create( :name => find_by_name, :presentation => find_by_name.humanize)
            logger.info "Created New Property #{property.inspect}"
          end

          if(property)
            # Property now protected from mass assignment
            x = product_property_klass.new( :value => find_by_value )
            x.property = property
            x.save
            @product_load_object.product_properties << x
            logger.info "Created New ProductProperty #{x.inspect}"
          else
            puts "WARNING: Property #{find_by_name} NOT found - Not set Product"
          end

        end

      end

      # Nested tree structure support ..
      # TAXON FORMAT
      # name|name>child>child|name

      def add_taxons
        # TODO smart column ordering to ensure always valid by time we get to associations
        product_load_object.save_if_new

        chain_list = value.to_s.split(multi_assoc_delim)  # potentially multiple chains in single column (delimited by multi_assoc_delim)

        chain_list.each do |chain|

          # Each chain can contain either a single Taxon, or the tree like structure parent>child>child
          name_list = chain.split(/\s*>\s*/)

          parent_name = name_list.shift

          parent_taxonomy = taxonomy_klass.where(:name => parent_name).first_or_create

          raise DataShift::DataProcessingError.new("Could not find or create Taxonomy #{parent_name}") unless parent_taxonomy

          parent = parent_taxonomy.root

          # Add the Taxons to Taxonomy from tree structure parent>child>child
          taxons = name_list.collect do |name|

            begin
              taxon = taxon_klass.where(:name => name, :parent_id => parent.id, :taxonomy_id => parent_taxonomy.id).first_or_create

              # pre Rails 4 -  taxon = taxon_klass.find_or_create_by_name_and_parent_id_and_taxonomy_id(name, parent && parent.id, parent_taxonomy.id)

              unless(taxon)
                logger.warn("Missing Taxon - could not find or create #{name} for parent #{parent_taxonomy.inspect}")
              end
            rescue => e
              logger.error(e.inspect)
              logger.error "Cannot assign Taxon ['#{taxon}'] to Product ['#{product_load_object.name}']"
              next
            end

            parent = taxon  # current taxon becomes next parent
            taxon
          end

          taxons << parent_taxonomy.root

          unique_list = taxons.compact.uniq - (@product_load_object.taxons || [])

          logger.debug("Product assigned to Taxons : #{unique_list.collect(&:name).inspect}")

          @product_load_object.taxons << unique_list unless(unique_list.empty?)
          # puts @product_load_object.taxons.inspect

        end

      end

      def add_variants_stock(data)

        product_load_object.save_if_new

        # do we have Variants?
        if(@product_load_object.variants.size > 0)

          logger.info "[COUNT_ON_HAND] - number of variants to process #{@product_load_object.variants.size}"

          if(data.to_s.include?(multi_assoc_delim))
            # Check if we've already processed Variants and assign count per variant
            values = data.to_s.split(multi_assoc_delim)
            # variants and count_on_hand number match?
            raise "WARNING: Count on hand entries did not match number of Variants - None Set" unless (@product_load_object.variants.size == values.size)
          end

          variants = @product_load_object.variants # just for readability and logic
          logger.info "Variants: #{@product_load_object.variants.inspect}"

          stock_coh_list = value.to_s.split(multi_assoc_delim) # we expect to get corresponding stock_location:count_on_hand for every variant

          stock_coh_list.each_with_index do |stock_coh, i|

            # count_on_hand column MUST HAVE "stock_location_name:variant_count_on_hand" format
            stock_location_name, variant_count_on_hand = stock_coh.split(name_value_delim)

            logger.info "Setting #{variant_count_on_hand} items for stock location #{stock_location_name}..."

            if not stock_location_name # No Stock Location referenced, fallback to default one...
              logger.info "No Stock Location was referenced. Adding count_on_hand to default Stock Location. Use 'stock_location_name:variant_count_on_hand' format to specify prefered Stock Location"
              stock_location = stock_location_klass.where(:default => true).first
              raise "WARNING: Can't set count_on_hand as no Stock Location exists!" unless stock_location
            else # go with the one specified...
              stock_location = stock_location_klass.where(:name => stock_location_name).first
              unless stock_location
                stock_location = stock_location_klass.create( :name => stock_location_name)
                logger.info "Created New Stock Location #{stock_location.inspect}"
              end
            end

            if(stock_location)
              stock_movement_klass.create(:quantity => variant_count_on_hand.to_i, :stock_item => variants[i].stock_items.find_by_stock_location_id(stock_location.id))
              logger.info "Added #{variant_count_on_hand} count_on_hand to Stock Location #{stock_location.inspect}"
            else
              puts "WARNING: Stock Location #{stock_location_name} NOT found - Can't set count_on_hand"
            end

          end

          # ... or just single Master Product?
        elsif(@product_load_object.variants.size == 0)
          if(data.to_s.include?(multi_assoc_delim))
            # count_on_hand column MUST HAVE "stock_location_name:master_count_on_hand" format
            stock_location_name, master_count_on_hand = (data.to_s.split(multi_assoc_delim).first).split(name_value_delim)
            puts "WARNING: Multiple count_on_hand values specified but no Variants/OptionTypes created"
          else
            stock_location_name, master_count_on_hand = data.split(name_value_delim)
          end
          if not stock_location_name # No Stock Location referenced, fallback to default one...
            logger.info "No Stock Location was referenced. Adding count_on_hand to default Stock Location. Use 'stock_location_name:master_count_on_hand' format to specify prefered Stock Location"
            stock_location = stock_location_klass.where(:default => true).first
            raise "WARNING: Can't set count_on_hand as no Stock Location exists!" unless stock_location
          else # go with the one specified...
            stock_location = stock_location_klass.where(:name => stock_location_name).first
            unless stock_location
              stock_location = stock_location_klass.create( :name => stock_location_name)
              logger.info "Created New Stock Location #{stock_location.inspect}"
            end
          end

          if(stock_location)
            stock_movement_klass.create(:quantity => master_count_on_hand.to_i, :stock_item => product_load_object.master.stock_items.find_by_stock_location_id(stock_location.id))
            logger.info "Added #{master_count_on_hand} count_on_hand to Stock Location #{stock_location.inspect}"
          else
            puts "WARNING: Stock Location #{stock_location_name} NOT found - Can't set count_on_hand"
          end
        end
      end

      def add_variant_images(data)

        product_load_object.save_if_new

        # do we have Variants?
        if(@product_load_object.variants.size > 0)

          logger.info "[VARIANT IMAGES] - number of variants to process #{@product_load_object.variants.size}"

          if(data.to_s.include?(multi_assoc_delim))
            # Check if we've already processed Variants and assign count per variant
            values = data.to_s.split(multi_assoc_delim)
            # variants and variant_images number match?
            raise "WARNING: Variant Images entries did not match number of Variants - None Set" unless (@product_load_object.variants.size == values.size)
          end

          variants = @product_load_object.variants

          logger.info "Variants: #{variants.inspect}"

          # we expect to get corresponding images for every variant (might have more than one image for each variant!)
          variants_images_list = value.to_s.split(multi_assoc_delim)

          variants_images_list.each_with_index do |variant_images, i|

            if(variant_images.to_s.include?(multi_value_delim))
              # multiple images
              images = variant_images.to_s.split(multi_value_delim)
            else
              # single image
              images = []
              images << variant_images
            end

            logger.info "Setting #{images.count} images for variant #{variants[i].name}..."

            # reset variant images to attach to variant
            var_images = []

            # Image processing...
            logger.debug "Images to process: #{images.inspect} for variant #{variants[i].name}"
            images.each do |image|
              @spree_uri_regexp ||= Regexp::new('(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?' )

              if(image.match(@spree_uri_regexp))

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
                extname = File.extname( uri.gsub(/\?.*=.*/, ''))

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

                alt_text = variants[i].name if !alt_text #ensure alt_text is filled

                logger.debug("Processing IMAGE from PATH #{path.inspect} #{alt_text.inspect}")

                path = File.join(config[:image_path_prefix], path) if(config[:image_path_prefix])

                attachment = create_attachment(Spree::Image, path, nil, nil, :alt => alt_text)

              end

              logger.debug "#{attachment.inspect}"
              var_images << attachment if attachment

            end # images loop

            # we have our variant images. Save them!
            begin
              # Link images to corresponding variant
              variants[i].images << var_images
              variants[i].save
              logger.debug("Variant assigned Images from : #{var_images.inspect}")
            rescue => e
              puts "ERROR - Failed to assign attachments to #{variants[i].class} #{variants[i].id}"
              logger.error("Failed to assign attachments to #{variants[i].class} #{variants[i].id}")
            end

          end # variants_images_list loop

          # ... or just single Master Product?
        elsif(@product_load_object.variants.size == 0)

          if(data.to_s.include?(multi_value_delim))
            # multiple images
            images = data.to_s.split(multi_value_delim)
          else
            # single image
            images << variant_images
          end

          logger.info "Setting #{images.count} images for Master variant #{@product_load_object.master.name}..."

          # Image processing...
          images.each do |image|
            @spree_uri_regexp ||= Regexp::new('(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:\/~\+#]*[\w\-\@?^=%&amp;\/~\+#])?' )

            if(image.match(@spree_uri_regexp))

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
              extname = File.extname( uri.gsub(/\?.*=.*/, ''))

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

              alt_text = @product_load_object.master.name if !alt_text #ensure alt_text is filled

              logger.debug("Processing IMAGE from PATH #{path.inspect} #{alt_text.inspect}")

              path = File.join(config[:image_path_prefix], path) if(config[:image_path_prefix])

              # create_attachment(klass, attachment_path, product_load_object = nil, attach_to_product_load_object_field = nil, options = {})
              attachment = create_attachment(Spree::Image, path, nil, nil, :alt => alt_text)

            end

            var_images << attachment if attachment

          end # images loop

          # we have our variant images. Save them!
          begin
            # Link images to corresponding variant
            @product_load_object.master.images << var_images
            @product_load_object.master.save
            logger.debug("Master Variant assigned Images from : #{var_images.inspect}")
          rescue => e
            puts "ERROR - Failed to assign attachment to #{@product_load_object.master.class} #{@product_load_object.master.id}"
            logger.error("Failed to assign attachment to #{@product_load_object.master.class} #{@product_load_object.master.id}")
          end

        end
      end

    end
  end
end
