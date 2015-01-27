# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Aug 2015
# License::   MIT
#
# Details::   Helpers to build Spree Promo Rules+ Actions
#

module DataShift

  module SpreeEcom

    # Adjust only Specific Items examples :
    #     10% off collections
    #     $36.00 off of the Picks (once per order)
    #
    class  WithProductRuleAdjustment

      include DataShift::Logging

      def initialize(promo, calculator, description)

        logger.error("Creating WithProductRuleAdjustment from [#{description}]")

        Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promo)

        # $36.00 off of the Picks (once per order)
        if(description.match(/off of the (\S+)\s+/) || description.match(/off (\S+)\s*/))

          logger.info("Searching for Products matching [%#{$1}%]")

          product_ids = Spree::Product.select( :id, :name ).where(Spree::Product.arel_table[:name].matches("%#{$1}%")).all

          if(product_ids.empty?)
            logger.error("No Matching Products found for  [%#{$1}%]")
          else
            logger.info("Found Matching Products : [#{product_ids.collect(&:name)}]")

            ids = product_ids.each {|p| p.id }

            logger.info("Creating Promo Rule for specific Products [#{ids.inspect}]")

            rule = Spree::Promotion::Rules::Product.create!(product_ids: ids)

            promo.rules << rule
          end
        else
          logger.error("Failed to parse [#{description}] - No Product Rule assigned")
        end
      end
    end


    # Simple - just adjust whole Order, every time
    class  WithOrderAdjustment

      include DataShift::Logging

      def initialize(promo, calculator, description = nil)

        action = Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator)
        promo.actions << action
      end
    end


    # Adjustment can only be applied Once per Order

    class  WithOncePerOrderRuleAdjustment

      include DataShift::Logging

      def initialize(promo, calculator, description = nil)

        # $36.00 off of the Picks (once per order) requires a Rule
        #TODO ????
      end
    end

    # Adjust whole Order but only if conditions met e.g Order over $25
    # TOFIX DONE
    class WithItemTotalRule

      include DataShift::Logging

      def initialize(promo, calculator, description)

        action = Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator)
        promo.actions << action

        # $10 off orders equal or above $25.00
        if(description.match("orders (\D+) \$(\d+\.\d*)"))

          logger.info("Creating Promo Rule for Min Amount of [#{$2}]")
          rule = Spree::Promotion::Rules::ItemTotal.create!(
              preferred_operator_min: 'gte',
              preferred_operator_max: 'lte',
              preferred_amount_min: $2.to_f,
              preferred_amount_max: nil
          )

          promo.rules << rule
        else
          logger.error("Failed to parse Shopify Promotion rule #{description} ")
        end
      end

    end

  end
end