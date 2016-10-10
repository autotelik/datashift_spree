# Copyright:: (c) Autotelik Media Ltd 2016
# Author ::   Tom Statter
# Date ::     2016
# License::   MIT
#
# Details::   Specific over-rides/additions to support Spree Products
#
require 'spree_ecom'

module DataShift

  module SpreeEcom

    class ProductLoader

      include SpreeLoading

      attr_accessor :datashift_loader

      # Non Product database fields we can still process - delegated to Variant
      #
      # See delegate_belongs_to :master @ https://github.com/spree/spree/blob/master/core/app/models/spree/product.rb
      #
      def force_inclusion_columns
        @force_inclusion_columns ||= %w{ cost_price
                                         images
                                         price
                                         shipping_category
                                         sku
                                         stock_items
                                         variant_sku
                                         variant_cost_price
                                         variant_price
                                         variant_images
        }
      end

      def run(file_name)

        DataShift::PopulatorFactory.global_populator_class = DataShift::SpreeEcom::ProductPopulator

        logger.info "Product load from File [#{file_name}]"

        DataShift::Configuration.call.force_inclusion_of_columns = force_inclusion_columns

        # gets a file type specific loader e.g csv, excel
        @datashift_loader = DataShift::Loader::Factory.get_loader(file_name)

        datashift_loader.run(file_name, product_klass)
      end

    end
  end
end
