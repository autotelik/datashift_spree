# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Mar 2013
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for loading Spree Digitals 

#
require File.join(File.expand_path(File.dirname(__FILE__) ), "spec_helper")

require 'product_loader'

describe 'Spree Digitals Loader' do

  before(:all) do
    before_all_spree
  end


  before(:each) do
  end

  # Operation and results should be identical when loading multiple associations
  # if using either single column embedded syntax, or one column per entry.

  it "should load Products and create Variants from single column" do


    include DataShift::Logging

    cmd = [
      '--attachment-klass',        'Spree::Digital', 
      '--attach-to-klass',         'Spree::Variant',  
      '--attach-to-find-by-field', 'sku',
      '--attach-to-field',         'digitals']
      
    # which boils down to
    # 
    # Variant.find_by_sku('sku_001').digitals << Spree::Digital.new( File.read('sku_001.mp3') )
      
    cmd << '--input' << File.join(fixtures_path(), 'digitals')
     
    puts "Running attach with: #{cmd}"
    invoke('datashift:paperclip:attach', [], cmd)

  end

end