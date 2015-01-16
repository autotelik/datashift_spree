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

            @sheet.each_with_index do |row, i|

              @current_row = row

              next if(i == header_row_index)

              # Excel num_rows seems to return all 'visible' rows, which appears to be greater than the actual data rows
              # (TODO - write spec to process .xls with a huge number of rows)
              #
              # This is rubbish but currently manually detect when actual data ends, this isn't very smart but
              # got no better idea than ending once we hit the first completely empty row
              break if(@current_row.nil? || @current_row.compact.empty?)

              logger.info "Processing Row #{i} : #{@current_row}"

              # Teh spreadsheet contains some lines that don't forget to reset the object or we'll update rather than create
              if(@current_row[2].nil? || @current_row[2].empty?)   # Financial Status
                # process the extra Lineitems
                process_line_items( @current_row )
                next
              else
                new_load_object
              end

              contains_data = false

              begin
                # First assign any default values for columns
                process_defaults

                # TODO - Smart sorting of column processing order ....
                # Does not currently ensure mandatory columns (for valid?) processed first but model needs saving
                # before associations can be processed so user should ensure mandatory columns are prior to associations

                # as part of this we also attempt to save early, for example before assigning to
                # has_and_belongs_to associations which require the load_object has an id for the join table

                # Iterate over method_details, working on data out of associated Excel column
                method_mapper.method_details.each_with_index do |method_detail, i|

                  unless method_detail
                    logger.warn("No method_detail found for column (#{i})")
                    next # TODO populate unmapped with a real MethodDetail that is 'null' and create is_nil
                  end
                  logger.info "Processing Column #{method_detail.column_index} (#{method_detail.operator})"

                  value = @current_row[method_detail.column_index]

                  contains_data = true unless(value.nil? || value.to_s.empty?)

                  process(method_detail, value)
                end

                # This is rubbish but currently have to manually detect when actual data ends,
                # no other way to detect when we hit the first completely empty row
                break unless(contains_data == true)

              rescue => e
                @reporter.processed_object_count += 1

                failure(@current_row, true)

                if(verbose)
                  puts "perform_excel_load failed in row [#{i}] #{@current_row} - #{e.message} :"
                  puts e.backtrace
                end

                logger.error  "perform_excel_load failed in row [#{i}] #{@current_row} - #{e.message} :"
                logger.error e.backtrace.join("\n")

                # don't forget to reset the load object
                new_load_object
                next
              end

              break unless(contains_data == true)

              # currently here as we can only identify the end of a speadsheet by first empty row
              @reporter.processed_object_count += 1

              # TODO - make optional -  all or nothing or carry on and dump out the exception list at end

              unless(save)
                failure
                logger.error "Failed to save row [#{@current_row}]"
                logger.error load_object.errors.inspect if(load_object)
              else
                logger.info("Successfully SAVED Object with ID #{load_object.id} for Row #{@current_row}")
                @reporter.add_loaded_object(@load_object)
              end

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

      def process_line_items( row )
        # for now jujst hard codign the columns 16 (quantity) and 17 (variant)

        puts("Adding LineItems to Order - Variant #{row[17]} - Quantity #{row[16].to_i}")

        variant = Spree::Variant.where(:name => row[17]).first

        puts("Found Variant - Variant ID #{variant.id}") if(variant)

        if(row[16].to_i > 0)
          line_item = load_object.contents.add(variant, row[16].to_i,  oad_object.currency)
          unless line_item.valid?
            errors.add(:base, line_item.errors.messages.values.join(" "))
            logger.error("Unable to add LineItems to Order #{load_object.number} (#{load_object.id})")
          else
            logger.info("Added LineItems to Order #{load_object.number}")
          end
        end
      end

    end

  end
end