# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Aug 2015
# License::   MIT
#
# Details::   Helpers to build Spree Promo Rules+ Actions
#

module DataShift

  module SpreeEcom

    # Adjustment can only be applied Once per Order
    #     $36.00 off of the Picks (once per order)
    #
    class  WithFirstOrderRuleAdjustment

      include DataShift::Logging

      def initialize(promo, calculator, description = nil)

        # $36.00 off of the Picks (once per order)

        logger.info("Creating WithOncePerOrderRuleAdjustment from [#{description}]")

        Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promo)
        # Not sure which Action required ?
        # Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator, promotion: promo)

        Spree::Promotion::Rules::FirstOrder.create!(promotion: promo)
      end

    end

    # Adjust only Specific Items examples :
    #     10% off collections
    #     $36.00 off of the Picks
    #
    class  WithProductRuleAdjustment

      include DataShift::Logging

      def initialize(promo, calculator, description)

        logger.info("Creating WithProductRuleAdjustment from [#{description}]")

        Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promo)

        # Examples :
        # regexp 1 : $36.00 off of the Picks (once per order)
        # regexp 2 : 30% off Miss Popular
        #            10% off collections

        #
        if(description.match(/off of the (.+) \(.*/) ||  description.match(/off (.+)/)
        )

          product_name = $1.strip

          products = if(product_name.include?('collections') && Spree::Product.column_names.include?('is_collection'))
                          logger.info("Searching for Collections")
                          Spree::Product.where(is_collection: true).all
                        else
                          logger.info("Searching for Products matching [%#{product_name}%]")
                          Spree::Product.where(Spree::Product.arel_table[:name].matches("%#{product_name}%")).all
                        end

          if(products.empty?)
            logger.error("No Matching Products found for  [%#{product_name}%]")
          else
            logger.info("Found Matching Products : [#{products.collect(&:name)}]")

            ids = products.collect(&:id)

            logger.info("Creating Promo Rule for specific Products [#{ids.inspect}]")

            # Can't do one step - this chokes on invalid products - maybe cos of HABTM
            # rule = Spree::Promotion::Rules::Product.create( products: products, promotion: promo))

            rule = Spree::Promotion::Rules::Product.create(promotion: promo)

            rule.products << products

            #promo.rules << rule

            rule.save
          end
        else
          logger.error("WithProductRuleAdjustment Failed to parse Description [#{description}] - No Product Rule assigned to #{promo.inspect}")
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


    # Adjust whole Order but only if conditions met e.g Order over $25
    class WithItemTotalRule

      include DataShift::Logging

      def initialize(promo, calculator, description)

        @regexp1 ||=  Regexp.new('.*orders (.+) \$(\d+\.\d+)')
        @regexp2 ||=  Regexp.new('.*orders (.+) \$(\d+)')

        action = Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator)
        promo.actions << action

        # $10 off orders equal or above $25.00
        # xxx off orders equal or above $25.00
        if(description.match(@regexp1) || description.match(@regexp2))

          # $1 not currently used since only ever seen "equal or above" => 'gte'
          logger.info("Creating Promo Rule for Min Amount of [#{$2}]")
          rule = Spree::Promotion::Rules::ItemTotal.create( preferred_amount: $2.to_f)

          # 2-1 stable only supports order greater than, not these
              #preferred_operator_min: 'gte',
              #preferred_operator_max: 'lte',
              #rule.preferred_amount_min = $2.to_f
              #rule.preferred_amount_max =  nil

          promo.rules << rule
        else
          logger.error("WithItemTotalRule : Failed to parse Shopify description [#{description}]")
        end
      end

    end

  end
end