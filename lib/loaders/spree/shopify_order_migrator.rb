# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Aug 2015
# License::   MIT
#
# Details::   Supports migrating Shopify spreadsheets to Spree
#               Currently covers :
#                 Orders
#
require 'spree_base_loader'
require 'spree_ecom'

module DataShift

  module SpreeEcom

    class ShopifyOrderLoader < SpreeBaseLoader

      # Options
      #  
      #  :reload           : Force load of the method dictionary for object_class even if already loaded
      #  :verbose          : Verbose logging and to STDOUT
      #
      def initialize(klass, options = {})
        # We want the delegated methods so always include instance methods
        opts = {:instance_methods => true}.merge( options )

        super( klass, nil, opts)

        raise "Failed to create a #{klass.name} for loading" unless load_object
      end

      # OVER RIDES

      # Options:
      #   [:dummy]           : Perform a dummy run - attempt to load everything but then roll back
      #
      def perform_load( file_name, opts = {} )
        logger.info "Shopify perform_load for Orders from File [#{file_name}]"
        super(file_name, opts)
      end

      def perform_excel_load( file_name, options = {} )

        start_excel(file_name, options)

        begin
          puts "Dummy Run - Changes will be rolled back" if options[:dummy]

          load_object_class.transaction do

            Spree::Config[:track_inventory_levels] = false

            @sheet.each_with_index do |row, i|

              current_row_idx = i
              @current_row = row

              next if(i == header_row_index)

              # Excel num_rows seems to return all 'visible' rows, which appears to be greater than the actual data rows
              # (TODO - write spec to process .xls with a huge number of rows)
              #
              # This is rubbish but currently manually detect when actual data ends, this isn't very smart but
              # got no better idea than ending once we hit the first completely empty row
              break if(row.nil? || row.compact.empty?)

              logger.info "Processing Row #{current_row_idx} : #{row}"

              @reporter.processed_object_count += 1

              # The spreadsheet contains some lines that are LineItems only for previous Order row
              if(load_object.id && (!row[0].nil? && !row[0].empty?) && (row[2].nil? || row[2].empty?))   # Financial Status empty on LI rows

                begin
                  process_line_item( row, load_object )

                  @reporter.success_inbound_count += 1

                rescue => e
                  process_excel_failure(e, false)
                end

                next  # row contains NO OTHER data

              else
                new_load_object   # Main Order row, create new Spree::Order
              end

              @contains_data = false

              # A real Order
              begin

                process_excel_row( row )

                begin
                  logger.info("Order - Assigning User with email [#{row[1]}]")

                  load_object.user = Spree.user_class.where( :email =>  @current_row[1] ).first
                rescue => e
                  logger.warn("Could not assign User #{row[1]} to Order #{load_object.number}")
                end

                save_and_report

              rescue => e
                process_excel_failure(e)
                next
              end

              begin
                # make sure we also process the main Order rows, LineItem
                process_line_item( row, load_object )

                load_object.save
              rescue    # logged already
                next
              end

              # This is rubbish but currently have to manually detect when actual data ends,
              # no other way to detect when we hit the first completely empty row
              break unless(contains_data == true)

            end   # all rows processed

            if(options[:dummy])
              puts "Excel loading stage complete - Dummy run so Rolling Back."
              raise ActiveRecord::Rollback # Don't actually create/upload to DB if we are doing dummy run
            end

          end   # TRANSACTION N.B ActiveRecord::Rollback does not propagate outside of the containing transaction block

        rescue => e
          puts "ERROR: Excel loading failed : #{e.inspect}"
          raise e
        ensure
          report
        end
      end

      def process_line_item( row, order )
        # for now just hard coding the columns 16 (quantity) and 17 (variant name), 20 (variant sku)
        @quantity_header_idx ||= 16
        @price_header_idx ||= 18
        @sku_header_idx ||= 20      # Lineitem:sku


        # if by name ...
        # by name - product = Spree::Product.where(:name => row[17]).first
        # variant = product.master if(product)

        sku = row[@sku_header_idx]

        method_detail = DataShift::MethodDictionary.find_method_detail(Spree::Order, "LineItems" )

        # will perform substitutions etc
        @populator.prepare_data(method_detail, sku)

        variant = Spree::Variant.where(:sku => sku).first

        unless(variant)
          raise RecordNotFound.new("Failed to find Variant with sku [#{sku}] for LineItem")
        end

        logger.info("Processing LineItem - Found Variant [#{variant.sku}] (#{variant.name})") if(variant)

        quantity = row[@quantity_header_idx].to_i

        if(quantity > 0)

          price = row[@price_header_idx].to_f

          logger.info("Adding LineItem for #{sku} with Quantity #{quantity} to Order #{load_object.inspect}")

          # idea incase we need full stock management
          # variant.stock_items.first.adjust_count_on_hand(quantity)

          begin

            #TODO - Not sure about stocklocation ... something better than Spree::StockLocation.first ??

            Spree::Shipment.create(state: 'pending', order: order, stock_location: Spree::StockLocation.first)

            line_item = Spree::LineItem.new(:variant => variant,
                                          :quantity => quantity,
                                          :price => price,
                                          :order => order,
                                          :currency => order.currency)

            unless(line_item.valid?)
              logger.error("Invalid LineItem :  #{line_item.errors.messages.inspect}")
            else
              logger.info("Attempting to save new LineItem against Order #{order.number} (#{order.id})")
              line_item.save
              order.reload
              logger.info("Success - Added LineItems to Order #{order.number}")
            end
          rescue => e
            logger.error("Create LineItem failed for [#{sku}] Order #{order.number} (#{order.id}) - #{e.inspect}")
            raise
          end

        end
      end

    end

  end
end