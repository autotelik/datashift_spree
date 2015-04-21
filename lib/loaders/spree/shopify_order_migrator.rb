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

          checkout_flow do
            go_to_state :address
            go_to_state :complete
          end


          def confirmation_required?
            false;
          end

          def payment_required?
            false;
          end
        end

        line_item_rows = 0

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
                puts "Finished - Last Row #{current_row_idx} : #{row}"
                break
              end

              logger.info "Processing Row #{current_row_idx} : #{row}"

              @reporter.processed_object_count += 1

              # The spreadsheet contains some lines that are LineItems only for previous Order row
              if(!row[0].nil? && !row[0].empty?) && (row[2].nil? || row[2].empty?)   # Financial Status empty on LI rows

                puts("START processing Line Item Only #{current_row_idx} - #{row[0]} - #{row[17]} - #{row[16]}  -#{row[18]}")

                line_item_rows += 1

                if(load_object && load_object.id.nil?)
                  logger.warn "No parent Order for Line Item Only row"
                  next
                end

                logger.info "Line Item Only - add row to current Order : #{load_object.id} : #{load_object.number}"

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


              # A real Order row, not just LineItem

              logger.info("Start processing new Order from row #{current_row_idx}")

              puts("START processing new Order from row #{current_row_idx} - #{row[0]} - #{row[17]} - #{row[16]}  -#{row[18]}")

              begin
                # We are loading/migrating data - ensure emails not sent
                load_object.confirmation_delivered = true

                @total_idx ||= excel_headers.index('total' )
                @shipment_total_idx ||= excel_headers.index('shipment_total' )
                @additional_tax_total_idx ||= excel_headers.index('additional_tax_total' )
                @payment_total_idx ||= excel_headers.index('payment_total' )
                @promo_total_idx ||= excel_headers.index('promo_total' )

                @payment_state_idx ||= excel_headers.index('payment_state' )
                @shipment_state_idx ||= excel_headers.index('shipment_state' )

                @completed_at_idx ||= excel_headers.index('completed_at' )
                @paid_at_idx ||= excel_headers.index('Paid at' )
                @created_at_idx ||= excel_headers.index('Created at')

                @item_count_idx ||= excel_headers.index('item_count' )

                @shipping_method_idx ||= excel_headers.index("shipping_method:name")


                shipment_state = @current_row[@shipment_state_idx]
                payment_state =  @current_row[@payment_state_idx]

                if(payment_state == 'refunded' && shipment_state == 'pending')
                  new_load_object
                  next
                end

                load_object.shipment_state = shipment_state

                load_object.payment_state = payment_state


                #number	Email	payment_state	Paid at	shipment_state	completed_at	Accepts Marketing	Currency
                #	Discount Code	promo_total	shipping_method:name	Created at	item_count	Lineitem name	Lineitem price	Lineitem compare at price	LineItems sku	Lineitem requires shipping	Lineitem taxable	LineItems fulfillment status	Billing Name	Billing Street	bill_address:address1	Billing Address2	Billing Company	Billing City	Billing Zip	Billing Province	Billing Country	Billing Phone	Shipping Name	Shipping Street	ship_address:address1	Shipping Address2	Shipping Company	Shipping City	Shipping Zip	Shipping Province	Shipping Country	Shipping Phone	Notes	Note Attributes	Cancelled at	Payment Method	Payment Reference	Refunded Amount	Vendor	Id	Tags	Risk Level	Source	Lineitem discount

                load_object.number = @current_row[0]
                load_object.email = @current_row[1]
                load_object.currency = @current_row[7]

                load_object.item_count = row[@item_count_idx].to_f

                load_object.id = nil if(load_object.id == 0)   # why the hell is this 0 happening !?

                # We are loading/migrating data - try to ensure emails not sent
                load_object.confirmation_delivered = true

                save

                puts("Saved Order #{load_object.number} [#{load_object.id}]")

                logger.info("Saved Order #{load_object.number} [#{load_object.id}]")

                begin
                  logger.info("Order #{load_object.number} - Assigning User with email [#{row[1]}]")

                  user = Spree.user_class.where( :email =>  @current_row[1] ).first

                  if(user)
                    logger.info("Found User [#{row[1]}] - assign to #{load_object.number} (#{load_object.id}) ")
                    load_object.associate_user!(user)

                    # The user usually has address information attached so pull it if the order has no prepopulated addresses
                    load_object.ship_address = load_object.user.ship_address unless load_object.ship_address
                    load_object.bill_address = load_object.user.bill_address unless load_object.bill_address
                  end

                  def warn_no_address missing_obj
                    logger.warn("No #{missing_obj} Address info for Order #{load_object.number} (#{load_object.id})")

                    load_object.ship_address = nil
                    load_object.bill_address = nil
                  end

                  if(load_object.bill_address.nil? and load_object.ship_address.nil?)
                    warn_no_address "ship and bill"
                  elsif(load_object.ship_address.nil?)
                    if(load_object.bill_address.id.nil?)
                      warn_no_address "ship and bill id"
                    else
                      load_object.clone_billing_address
                    end
                  elsif(load_object.bill_address.nil?)
                    if(load_object.ship_address.id.nil?)
                      warn_no_address "bill and ship id"
                    else
                      load_object.bill_address.attributes = load_object.ship_address.attributes.except('id', 'updated_at', 'created_at')
                    end
                  elsif(load_object.bill_address.id.nil? and load_object.ship_address.nil?)
                    warn_no_address "bill id and ship id"
                  end

                rescue => e
                  logger.error("Error assigning User #{e.inspect}")
                  logger.warn("Could not assign User #{row[1]} to Order #{load_object.number}")
                end

                unless(load_object.valid?)
                  logger.info("INVALID ADDRESS - Order still Invalid #{load_object.inspect}")
                  logger.info("Valid Order #{load_object.valid?}")
                  puts "Row  #{current_row_idx} invalid  #{load_object.errors.full_messages.inspect}"
                  load_object.id = nil if(load_object.id == 0)   # why the hell is this 0 happening !?
                end

                begin
                  # make sure we also process the main Order rows, LineItem
                  process_line_item( row, load_object )
                  load_object.next!
                rescue => x    # logged already
                  puts "Issue assigning LineItem #{x.inspect}"
                end


                shipping_method = Spree::ShippingMethod.where( name:  @current_row[@shipping_method_idx]).first

                load_object.shipping_method_id = shipping_method.id if(shipping_method)

                load_object.completed_at = @current_row[@completed_at_idx].blank? ? @current_row[@paid_at_idx] : @current_row[@completed_at_idx]

                if(load_object.completed_at.blank?)
                  puts "No suitable completed_at date - using Created at #{@current_row[@created_at_idx]}"

                  load_object.completed_at = @current_row[@created_at_idx]
                end

                load_object.shipment_total = row[@shipment_total_idx].to_f
                load_object.promo_total = row[@promo_total_idx].to_f
                load_object.total = row[@total_idx].to_f

                load_object.id = nil if(load_object.id == 0)   # why the hell is this 0 happening !?

                save_and_report

              rescue => e
                puts "Save Failed #{e.inspect}"
                process_excel_failure(e)
                next
              end

            end   # all rows processed

            # double check the last Order
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

        puts "Line Item only row count : #{line_item_rows}"
      end

      def finish

        return unless(load_object && load_object.id)    # Ok we have added all Line Items - now complete existing order

        load_object.create_proposed_shipments

        # Spree::Order.shipments is a CollectionProxy (empty if no shipments)
        # so each is safe to use
        load_object.shipments.each do |s|
          s.state = 'shipped'
          s.shipped_at = load_object.completed_at
        end

        load_object.payment_state = 'paid'
        load_object.shipment_state = 'shipped'
        load_object.state = 'complete'

        logger.info("Order #{load_object.id}(#{load_object.number}) state set to 'complete' - Final Save")

        load_object.id = nil if(load_object.id == 0)   # why the hell is this 0 happening !?

        begin
          load_object.save!    # ok this Order done
        rescue => x
          logger.error("Final Spree Order save failed : #{load_object.errors.full_messages.inspect}")
          puts x.inspect
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

          if(order.new_record?)
            puts "ORDER NEEDS SAVING - #{order.number} (#{order.id})"
            save
          end

          # idea incase we need full stock management
          # variant.stock_items.first.adjust_count_on_hand(quantity)

          begin
            #puts("Adding LineItem for #{sku} with Quantity #{quantity} to Order #{load_object.inspect}")
            #puts("Variant [#{variant.sku}] (#{variant.name})") if(variant)

            logger.info("Attempting to add new LineItem against Order #{order.number} (#{order.id})")

            order.line_items.new(quantity: quantity, variant: variant, :price => price)
=begin

            line_item = Spree::LineItem.create!(:variant => variant,
                                            :quantity => quantity,
                                            :price => price,
                                            :pre_tax_amount => price,
                                            :order => order,
                                            :currency => order.currency)


             # line_item.save
              #order.reload

              logger.info("Success - Added LineItems to Order #{order.number} (#{order.id})")
            end
=end
          rescue => e
            puts("Create LineItem failed for [#{sku}] Order #{order.number} (#{order.id}) - #{e.inspect}")
            puts("Create LineItem failed for [#{sku}] Order #{order.number} (#{order.id}) - #{e.inspect}")
            logger.error("Create LineItem failed for [#{sku}] Order #{order.number} (#{order.id}) - #{e.inspect}")
            raise
          end

        end
      end

    end

  end
end
