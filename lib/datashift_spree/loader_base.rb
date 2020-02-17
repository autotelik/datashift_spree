# Copyright:: (c) Autotelik Media Ltd 2020
# Author ::   Tom Statter
# License::   MIT
#
# Details::   Specific over-rides/additions to support Spree Products
#
require_relative 'loading'

module DataShiftSpree

  class LoaderBase

    include DataShift::ImageLoading
    include DataShiftSpree::Loading

    def initialize
      super
    end

  end
end
