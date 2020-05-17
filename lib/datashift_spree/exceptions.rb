# Copyright:: (c) Autotelik B.V 2014
# Author ::   Tom Statter
# Date ::     June 2014
# License::   Free, Open Source.
#

module DataShift

  module Spree

    class ProductLoadError < DataShift::DataShiftException
      def initialize( msg )
        super( msg )
      end
    end
  
    class ImageLoadError < DataShift::DataShiftException
      def initialize( msg )
        super( msg )
      end
    end
    
  end
end