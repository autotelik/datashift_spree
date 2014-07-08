# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Mar 2013
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for loading Spree Digitals 

#
require File.join(File.expand_path(File.dirname(__FILE__) ), "spec_helper")


describe 'Datshift Spree Thor tasks' do

  before(:all) do
    @spree_sandbox_app_path = DataShift::SpreeHelper::spree_sandbox_path 
    
    require 'thor'    
    require 'thor/runner'
    
    load  File.join(rspec_spree_thor_path, 'digitals.thor')
    
  end


  before(:each) do
  end

  
  it "should bulk attach digitals to a Product" do

    cmd = ["bulk",  '--field', 'sku']
      
    # which boils down to
    # 
    # Variant.find_by_sku('sku_001').digitals << Spree::Digital.new( File.read('sku_001.mp3') )
      
    cmd << '--input' << File.join(fixtures_path(), 'digitals')
     
    puts "Running bulk attach  #{cmd}"
    
    rails_sandbox_root = DataShift::SpreeHelper::spree_sandbox_path
         
    run_in(rails_sandbox_root)  do
      DatashiftSpree::Digitals.start( cmd)
    end

  end
  
  # Operation and results should be identical when loading multiple associations
  # if using either single column embedded syntax, or one column per entry.

  it "should attach Images to Products from a directory" do

    pending "better undserstanding of rspec + thor testing"
    args =  '--attachment-klass Spree::Image --attach-to-klass Spree::Variant --attach-to-find-by-field sku'
    args << ' --attach-to-field digitals'
      
    # which boils down to
    # 
    # Variant.find_by_sku('sku_001').digitals << Spree::Digital.new( File.read('sku_001.mp3') )
      
    args << " --input #{File.join(fixtures_path(), 'digitals')}"
     
    puts "Running attach with: #{args}"
    
    run_in(@spree_sandbox_app_path) do
      
    
      x = capture(:stdout){ system("bundle exec thor datashift:paperclip:attach " +  args)  }
      x.should start_with("datashift\n--------")
      x.should =~ / csv -i/
      x.should =~ / excel -i/
    end

  end

end
