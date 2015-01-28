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
        opts = {:instance_methods => true }.merge( options )

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

        # Spree 2 Checkout/Order states

        #       go_to_state :address
        #       go_to_state :delivery
        #       go_to_state :payment, if: ->(order) { order.payment_required? }
        #       go_to_state :confirm, if: ->(order) { order.confirmation_required? }
        #       go_to_state :complete

        Spree::Order.class_eval do
          def confirmation_required?
            false;
          end

          def payment_required?
            false;
          end
        end

        start_excel(file_name, options)

        begin
          puts "Dummy Run - Changes will be rolled back" if options[:dummy]
          load_object_class.transaction do

            Spree::Config[:track_inventory_levels] = false

            @sheet.each_with_index do |row, i|

              current_row_idx = i
              @current_row = row

              next if(i == header_row_index)

              # This required in some circumstances where each_with_index keeps going
              # so need to manually detect when actual data ends, so quit once we hit the first completely empty row
              if(row.nil? || row.compact.empty?)
                break
              end

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
                finish if(load_object.id)    # Ok we have added all Line Items - now complete existing order

                new_load_object   # Main Order row, create new Spree::Order
              end

              @contains_data = false

              # A real Order row, not just LineItem

              begin
                # We are loading/migrating data - ensure emails not sent
                load_object.confirmation_delivered = true

                process_excel_row( row )

                begin
                  # make sure we also process the main Order rows, LineItem
                  process_line_item( row, load_object )
                rescue    # logged already
                end

                save

                # We are loading/migrating data - try to ensure emails not sent
                load_object.confirmation_delivered = true

                begin
                  logger.info("Order - Assigning User with email [#{row[1]}]")

                  load_object.next  #address

                  load_object.associate_user!( Spree.user_class.where( :email =>  @current_row[1] ).first)
                rescue => e
                  logger.warn("Could not assign User #{row[1]} to Order #{load_object.number}")
                end

                @total_idx ||= excel_headers.index('total' )
                @shipment_total_idx ||= excel_headers.index('shipment_total' )
                @additional_tax_total_idx ||= excel_headers.index('additional_tax_total' )
                @payment_total_idx ||= excel_headers.index('payment_total' )
                @promo_total_idx ||= excel_headers.index('promo_total' )

                @payment_state_idx ||= excel_headers.index('payment_state' )

                load_object.shipment_total = row[@shipment_total_idx].to_f
                load_object.promo_total = row[@promo_total_idx].to_f
                load_object.total = row[@total_idx].to_f


                save_and_report

              rescue => e
                process_excel_failure(e)
                next
              end

              # This is rubbish but currently have to manually detect when actual data ends,
              # no other way to detect when we hit the first completely empty row
              unless(contains_data == true)
                break
              end

            end   # all rows processed

            finish

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

      def finish

        return unless(load_object && load_object.id)    # Ok we have added all Line Items - now complete existing order

        load_object.create_proposed_shipments

        if(load_object.shipments.first)
          load_object.shipments.first.state =  'shipped'
          load_object.shipments.first.shipped_at = load_object.completed_at
        end

        load_object.payment_state = "paid"

        load_object.state = 'complete'

        load_object.save    # ok this Order done
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