# Copyright:: (c) Autotelik Media Ltd 2014 
# Author ::   Tom Statter
# Date ::     June 2014
# License::   Free, Open Source.
#

module DataShifSpree

  class ProductLoadError < DataShift::DataShiftException
    def initialize( msg )
      super( msg )
    end
  end
  
  
end