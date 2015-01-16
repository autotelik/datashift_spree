# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     March 2015
# License::   MIT. Free, Open Source.
#
# Note, not DataShift, case sensitive, create namespace for command line : datashift

require 'datashift_spree'

require 'spree_ecom'

module DatashiftSpree
  
  class Shopify < Thor

    include DataShift::Logging

    desc "orders", "Populate Spree Order data from Shopify .xls (Excel) or CSV file"

    method_option :input, :aliases => '-i', :required => true, :desc => "The import file (.xls or .csv)"
    method_option :image_path_prefix, :aliases => '-p', :desc => "Prefix to add to image path for importing from disk"
    method_option :verbose, :aliases => '-v', :type => :boolean, :desc => "Verbose logging"
    method_option :config, :aliases => '-c',  :type => :string, :desc => "Configuration file containg defaults or over rides in YAML"
    method_option :dummy, :aliases => '-d', :type => :boolean, :desc => "Dummy run, do not actually save Image or Product"

    def orders()

      # TODO - We're assuming run from a rails app/top level dir...
      # ...can we make this more robust ? e.g what about when using active record but not in Rails app,
      require File.expand_path('config/environment.rb')

      input = options[:input]

      require 'shopify_loader'

      loader = DataShift::SpreeEcom::ShopifyOrderLoader.new( Spree::Order, {:verbose => options[:verbose]})

      # YAML configuration file to drive defaults etc

      if(options[:config])
        raise "Bad Config - Cannot find specified file #{options[:config]}" unless File.exists?(options[:config])

        puts "DataShift::Product processing config from: #{options[:config]}"

        loader.configure_from( options[:config] )
      end

      loader.perform_load(input, options)
    end

  end
end