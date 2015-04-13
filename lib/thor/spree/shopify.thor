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


    desc "users", "Populate Spree User data from Shopify .xls (Excel) or CSV file"

    method_option :input, :aliases => '-i', :required => true, :desc => "The import file (.xls or .csv)"
    method_option :config, :aliases => '-c',  :type => :string, :desc => "Configuration file containg defaults or over rides in YAML"
    method_option :dummy, :aliases => '-d', :type => :boolean, :desc => "Dummy run, do not actually save Image or Product"

    def users()

      # We're assuming run from a rails app/top level dir
      require File.expand_path('config/environment.rb')

      max_user = Alchemy::User.last.id

      begin
        invoke 'datashift:import:csv', [], options.merge({model: Alchemy::User})
      rescue => e
        log :error, "Fcm Config was not validated. Please check log above, fix and rerun"
        exit(-1)
      end

      default_password = SecureRandom.hex(13)

      puts "default_password is #{default_password}"

      users =  Alchemy::User.where( "id > ?", max_user )
    end


    desc "promos", "Populate Spree Promotion data from Shopify .xls (Excel) or CSV file"

    method_option :input, :aliases => '-i', :required => true, :desc => "The import file (.xls or .csv)"
    method_option :verbose, :aliases => '-v', :type => :boolean, :desc => "Verbose logging"
    method_option :config, :aliases => '-c',  :type => :string, :desc => "Configuration file containg defaults or over rides in YAML"
    method_option :dummy, :aliases => '-d', :type => :boolean, :desc => "Dummy run, do not actually save Image or Product"

    def promos()

      # We're assuming run from a rails app/top level dir
      require File.expand_path('config/environment.rb')

      input = options[:input]

      require 'shopify_promotions_migrator'

      loader = DataShift::SpreeEcom::ShopifyPromotionsMigrator.new(:verbose => options[:verbose])

      # YAML configuration file to drive defaults etc

      if(options[:config])
        raise "Bad Config - Cannot find specified file #{options[:config]}" unless File.exists?(options[:config])

        puts "Processing config from: #{options[:config]}"

        loader.configure_from( options[:config] )
      end

      loader.perform_load(input, options)
    end


    desc "report_promo_data", "Report on available Spree Promotion data - rules/calculators etc"

    def report_promo_data()

      # We're assuming run from a rails app/top level dir
      require File.expand_path('config/environment.rb')

      puts "\n*** Spree::Promotion columns***"
      puts "\t#{Spree::Promotion.columns.map(&:name).inspect}\n"

      # get the available Rules
      rules = Rails.application.config.spree.promotions.rules

      puts "\n*** Available Rules***"
      rules.each {|x| puts "\t#{x.inspect}\n" }

      calculators = Rails.application.config.spree.calculators.promotion_actions_create_adjustments
      puts "\n*** Available Calculators***"
      calculators.each {|x| puts "\t#{x.inspect}\n" }

    end

    desc "orders", "Populate Spree Order data from Shopify .xls (Excel) or CSV file"

    method_option :input, :aliases => '-i', :required => true, :desc => "The import file (.xls or .csv)"
    method_option :verbose, :aliases => '-v', :type => :boolean, :desc => "Verbose logging"
    method_option :config, :aliases => '-c',  :type => :string, :desc => "Configuration file containg defaults or over rides in YAML"
    method_option :dummy, :aliases => '-d', :type => :boolean, :desc => "Dummy run, do not actually save Image or Product"
    method_option :delete_existing,  :type => :boolean, :desc => "WARNING - test mode delete existing Orders first"

    def orders()

      # assuming run from a rails app/top level dir...
      require File.expand_path('config/environment.rb')

      # Use default logging formatter so that PID and timestamp are not suppressed.
      Rails.application.config.log_formatter = ::Logger::Formatter.new


      if(options[:delete_existing])
        puts "DELETING ALL ORDERS!!!!!!!"
        sleep 1
        Spree::Order.delete_all
        Spree::LineItem.delete_all
        puts "DELETED ALL ORDERS!!!!!!!"
      end
      input = options[:input]

      require 'shopify_order_migrator'

      loader = DataShift::SpreeEcom::ShopifyOrderLoader.new( Spree::Order, {:verbose => options[:verbose]})

      # YAML configuration file to drive defaults etc

      if(options[:config])
        raise "Bad Config - Cannot find specified file #{options[:config]}" unless File.exists?(options[:config])

        puts "Processing config from: #{options[:config]}"

        loader.configure_from( options[:config] )
      end

      loader.perform_load(input, options)

      puts "Spree Order count now : #{Spree::Order.count}"

    end



  end
end