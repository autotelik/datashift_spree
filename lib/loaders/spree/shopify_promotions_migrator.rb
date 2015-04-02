# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Aug 2015
# License::   MIT
#
# Details::   Supports migrating Shopify spreadsheets to Spree
#               Currently covers :
#                 Promotions
#
require 'spree_base_loader'
require 'spree_ecom'
require 'promotions_rules_actions.rb'

module DataShift

  module SpreeEcom

    class ShopifyPromotionsMigrator < SpreeBaseLoader

      # Options
      #  
      #  :reload           : Force load of the method dictionary for object_class even if already loaded
      #  :verbose          : Verbose logging and to STDOUT
      #
      def initialize(options = {})
        # We want the delegated methods so always include instance methods
        opts = {:instance_methods => true}.merge( options )

        super(Spree::Promotion, nil, opts)

        raise "Failed to create a #{klass.name} for loading" unless load_object
      end

      # OVER RIDES

      # Options:
      #   [:dummy]           : Perform a dummy run - attempt to load everything but then roll back
      #
      def perform_load( file_name, opts = {} )
        logger.info "Shopify perform_load for Promotions from File [#{file_name}]"
        super(file_name, opts)
      end

      def perform_excel_load( file_name, options = {} )

        start_excel(file_name, options)

        begin
          puts "Dummy Run - Changes will be rolled back" if options[:dummy]

          load_object_class.transaction do

            # Rule seems to be (amount)(description)
            desc_splitter_regex = Regexp.new('^(\S+)\s(.*)')

            rate_regex = Regexp.new('(\d+)\%')

            dollar_amount_regex1 = Regexp.new('\$(\d+\.\d*)')
            dollar_amount_regex2 = Regexp.new('\$(\d+)\s*')

            #  e.g 1           : \d => number used, no usage limit
            #  e.g 2/10        : \d/\d e.g 2/10 => number used / max usage limit
            #  e.g 1 out of 1  : \d/ out of \d  => number used / max usage limit
            limit_regexp1 = Regexp.new('(\d+)\/(\d+)')
            limit_regexp2 = Regexp.new('(\d+) out of (\d+)')

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

              new_load_object   # Main Order row, create new Spree::Order

              @contains_data = false

              begin

                process_excel_row( row )

                load_object.code = load_object.name

                shopify_usage_rule = row[2].to_s

                if(shopify_usage_rule.match(limit_regexp1))
                  load_object.historical_usage = $1.to_i
                  load_object.usage_limit =  $2.to_f
                  logger.info("Promo has usage (#{$1}) - Limit Set : [#{$2}]")

                elsif(shopify_usage_rule.match(limit_regexp2))
                  load_object.historical_usage = $1.to_i
                  load_object.usage_limit =  $2.to_f
                  logger.info("Promo has usage (#{$1}) - Limit Set : [#{$2}]")

                else
                  load_object.historical_usage = shopify_usage_rule.to_i

                end

                # TODO - not sure any way to set used - looks like Spree calculates it from orders

                # Name	description	Used	starts_at	expires_at
                shopify_rule_action = row[1]

                # 15% off all orders
                # $70.00 off all orders
                # $10 off orders equal or above $25.00
                # $15.00 OFF ORDERS EQUAL OR ABOVE $75.00
                # 10% off collections
                # $36.00 off of the Picks (once per order)

                logger.info("Parsing Shopify Details for Rules/Actions : [#{shopify_rule_action}]")

                rule_action = shopify_rule_action.match(desc_splitter_regex)

                if(rule_action)

                  calc_portion = $1.dup
                  desc_portion = $2.downcase

                  rule_action = shopify_rule_action.match(desc_splitter_regex)

                  adjustment = if(desc_portion.include?("or above"))          # $10 off orders equal or above $25.00 - requires a Rule
                                 WithItemTotalRule
                               elsif(desc_portion.include?("once per order"))
                                 # TODO Not sure this is correct - once per order may just be same WithOrderAdjustment
                                 WithFirstOrderRuleAdjustment
                               elsif(desc_portion.include?("all orders") || desc_portion == 'off')      # nice n simple - no rules/products
                                 WithOrderAdjustment
                               else
                                 WithProductRuleAdjustment      #DONE                      # requires a specific Product e.g Picks or collections
                               end

                  logger.info("Creating Adjustment of type : [#{adjustment}]")

                  if(calc_portion.match(rate_regex))
                    adjustment_rate = $1.to_f

                    logger.info("Percentage Rate adjustment : [#{adjustment}]")

                    calculator = Spree::Calculator::FlatPercentItemTotal.new
                    calculator.preferred_flat_percent = adjustment_rate

                    adjustment.new(load_object, calculator, desc_portion)

                  elsif(calc_portion.match(dollar_amount_regex1) || calc_portion.match(dollar_amount_regex2) )
                    adjustment_rate = $1.to_f

                    logger.info("Dollar Amount adjustment : [#{adjustment_rate}]")

                    calculator = Spree::Calculator::FlatRate.new
                    calculator.preferred_amount =  adjustment_rate

                    adjustment.new(load_object, calculator, desc_portion)

                  else
                    logger.error("Failed to parse Shopify amount from [#{calc_portion}]")
                  end

                end

                save_and_report

              rescue => e
                process_excel_failure(e)
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

    end

  end
end
