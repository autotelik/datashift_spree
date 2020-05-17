# Copyright:: (c) Autotelik B.V 2020
# Author ::   Tom Statter
# License::   MIT
#
# Details::   Specific over-rides/additions to support Spree Products
#
require_relative 'loading'

module DatashiftSpree

  class LoaderBase

    include DataShift::ImageLoading
    include DatashiftSpree::Loading

    def initialize
      super
    end

  end
end
