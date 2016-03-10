# Copyright:: (c) Autotelik Media Ltd 2014 
# Author ::   Tom Statter
# Date ::     June 2014
# License::   Free, Open Source.
#
require 'datashift/exceptions'

module DataShift

  module SpreeEcom

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
