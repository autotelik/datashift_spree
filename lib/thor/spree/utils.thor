# Copyright:: (c) Autotelik Media Ltd 2012
# Author ::   Tom Statter
# Date ::     March 2012
# License::   MIT. Free, Open Source.
#
# Usage::
# bundle exec thor help datashift:spreeboot
# bundle exec thor datashift:spreeboot:cleanup
#
# Note, not DataShift, case sensitive, create namespace for command line : datashift

module DatashiftSpree
        
  class Utils < Thor     
  
    include DataShift::Logging
       
    desc "cleanup", "Remove Spree Product/Variant data from DB"
    
    method_option :taxons, :aliases => '-t', :type => :boolean, :desc => "WARNING : deletes whole Taxonomy tree"

    def cleanup()

      require File.expand_path('config/environment.rb')

      require 'spree_helper'

      require File.expand_path('config/environment.rb')

      ActiveRecord::Base.connection.execute("TRUNCATE spree_products_taxons")
      ActiveRecord::Base.connection.execute("TRUNCATE spree_products_promotion_rules")
      
      cleanup =  %w{ Image OptionType OptionValue 
                    Product Property ProductProperty ProductOptionType 
                    Variant
      }

      cleanup += ["Taxonomy", "Taxon"] if(options[:taxons])
      
      cleanup.each do |k|
        klass = DataShift::SpreeHelper::get_spree_class(k)
        if(klass)
          puts "Clearing model #{klass}"
          begin
            klass.delete_all
          rescue => e
            puts e
          end
        else
          puts "WARNING - Could not find AR model for class name #{k}"
        end
      end
      
      image_bank = 'public/spree/products'
      
      if(File.exists?(image_bank) )
        puts "Removing old Product assets from '#{image_bank}'"
        FileUtils::rm_rf(image_bank) 
      end
      
      FileUtils::rm_rf('MissingRecords') if(File.exists?('MissingRecords') )
      
    end
  
  end
end