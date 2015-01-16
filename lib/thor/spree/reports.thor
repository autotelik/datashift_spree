# Copyright:: (c) Autotelik Media Ltd 2012
# Author ::   Tom Statter
# Date ::     March 2012
# License::   MIT. Free, Open Source.
#
# Usage::
# bundle exec thor help datashift:reports:missing_images
# bundle exec thor datashift:spreeboot:cleanup
#
# Note, not DataShift, case sensitive, create namespace for command line : datashift
  
module DatashiftSpree
        
    class Reports < Thor     
  
      include DataShift::Logging
       
      desc "no_image", "Spree Products without an image"
    
      def no_image(report = nil)

        require 'spree_ecom'
        require 'csv_exporter'
        require 'image_loader'
        require 'exporters/excel_exporter'
        require 'exporters/csv_exporter'

        require File.expand_path('config/environment.rb')

        klass = DataShift::SpreeEcom::get_spree_class('Product')
      
        missing = klass.all.find_all {|p| p.images.size == 0 }
      
        puts "There are #{missing.size} Products (of #{klass.count}) without an associated Image"
      
        fname = report ? report : "missing_images"
      
        if(DataShift::Guards::jruby?)
          puts "Creating report #{fname}.xls"  
          DataShift::ExcelExporter.new( fname + '.xls' ).export( missing, :methods => ['sku'] )
        else
          puts "Creating report #{fname}.csv"
          DataShift::CsvExporter.new( fname + '.csv' ).export( missing, :methods => ['sku'] )
          puts missing.collect(&:name).join('\n')
        end   
      
# TODO - cross check file locations for possible candidates 
        #image_cache = DataShift::ImageLoading::get_files(@cross_check_location, options)
        
        # missing.each { 
      
        # puts images.inspect
      end
    end

end
