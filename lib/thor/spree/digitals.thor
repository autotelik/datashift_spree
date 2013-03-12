# Copyright:: (c) Autotelik Media Ltd 2012
# Author ::   Tom Statter
# Date ::     March 2012
# License::   MIT. Free, Open Source.
#
# Usage::
# bundle exec thor help datashift:spree
# bundle exec thor datashift:spree:products -i db/datashift/MegamanFozz20111115_load.xls -s 299S_
#
# bundle exec thor  datashift:spree:images -i db/datashift/imagebank -s -p 299S_
#

# Note, not DataShift, case sensitive, create namespace for command line : datashift

require 'datashift_spree'

require 'spree_helper'

module DatashiftSpree 
  
  class Digitals < Thor

    include DataShift::Logging

    desc "bulk", "Attach digital assets to Spree Variant based on asset filename"
    
    method_option :input, :aliases => '-i', :required => true, :desc => "The import path containing assets"
  
    def bulk()

      # TODO - We're assuming run from a rails app/top level dir...
      # ...can we make this more robust ? e.g what about when using active record but not in Rails app,
      require File.expand_path('config/environment.rb')

      cmd = [
        '--attachment-klass', 'Spree::Digital', 
        '--attach-to-klass',  'Spree::Variant',  
        '--attach-to-find-by-field', 'sku',
        '--attach-to-field',         'digitals']
      
      # which boils down to
      # 
      # Variant.find_by_sku('sku_001').digitals << Spree::Digital.new( File.read('sku_001.mp3') )
      
      cmd << '--input' << options[:input]
     
      puts "Running attach with: #{cmd}"
      invoke('datashift:paperclip:attach', [], cmd)

    end

  end
end