# Copyright:: (c) Autotelik Media Ltd 2012
# Author ::   Tom Statter
# Date ::     Dec 2014
# License::   MIT. Free, Open Source.
#

require 'datashift_spree'


module DatashiftSpree 
  
  class Exports < Thor

    include DataShift::Logging

    desc "orders", "Export Spree Order data to .xls (Excel)"

    method_option :file, :aliases => '-f', :required => true, :desc => "Filename (.xls or .csv)"

    def orders()

      pass_options = {:verbose => true, :model => 'Spree::Order', :assoc => true, :result => options[:file] }

      invoke('datashift:export:excel', [], pass_options)

    end

  end
end