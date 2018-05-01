# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Mar 2013
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for loading Spree Digitals
#
require "spec_helper"
require 'thor'
require 'thor/runner'
require 'datashift'

describe 'Datshift Spree Thor tasks' do

  let(:spree_sandbox_app_path) { DataShift::SpreeEcom::spree_sandbox_path }

  before(:all) do
    DataShift.load_commands
    DataShift::SpreeEcom.load_commands
  end

  it 'should list available datashift thor tasks' do
    x = run_in(spree_sandbox_app_path) do
      capture(:stdout){ Thor::Runner.start(["list"]) }
    end

    expect(x).to include("datashift_spree\n--------")

    expect(x).to include "csv"
    expect(x).to include "products"
    expect(x).to include "images"
  end

  context 'IMPORT CLI' do

    it "should bulk attach digitals to a Product" do

      args = ['--field', 'sku', '--input', File.join(fixtures_path, 'digitals') ]

      run_in(spree_sandbox_app_path) do

        # which boils down to
        #
        # Variant.find_by_sku('sku_001').digitals << Spree::Digital.new( File.read('sku_001.mp3') )

        capture(:stdout) {
          DatashiftSpree::Digitals.new.invoke(:bulk, [], args)
        }

        pending "Work on Digitals"
        expect(Spree::Digital.count).to be > 0
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

end
