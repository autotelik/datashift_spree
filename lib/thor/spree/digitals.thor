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

    x=<<EOS
Spree::Digitals : Find Variants based on filename and attach associated digital file

    Most commonly you would embed the SKU or ID, for example:

        Given a Variant with SKU ABC_001 the digital filename should contain ABC_001 somewhere in it

          e.g ABC_001.pdf or "ABC_001 war and peace.pdf" or "warandpeace ABC_001.pdf
  
        Given a Variant with IS 124 the digital filename should contain 124 somehere clearly in it.

          e.g 124.pdf or "124 war and peace.pdf" or "warandpeace_124.pdf 

EOS
    
    desc "bulk", x
    
    method_option :input, :aliases => '-i', :required => true, :desc => "The import path containing assets"
    method_option :field, :aliases => '-f', :default => 'SKU', :desc => "The field to lookup the Variant"
    method_option :split_file_name_on,  :type => :string, :desc => "delimiter to progressivley split filename for lookup", :default => ' '

    def bulk()

      # TODO - We're assuming run from a rails app/top level dir...
      # ...can we make this more robust ? e.g what about when using active record but not in Rails app,
      require File.expand_path('config/environment.rb')

      cmd = [
        '--attachment-klass',        'Spree::Digital', 
        '--attach-to-klass',         'Spree::Variant',  
        '--attach-to-find-by-field',  options[:field],
        '--attach-to-field',         'digitals']
      
      # which boils down to
      # 
      # Variant.find_by_sku('sku_001').digitals << Spree::Digital.new( File.read('sku_001.mp3') )
      
      cmd << '--input' << options[:input] << '--split_file_name_on' << options[:split_file_name_on]
     
      puts "Running attach with: #{cmd}"
      invoke('datashift:paperclip:attach', [], cmd)

    end

  end
end