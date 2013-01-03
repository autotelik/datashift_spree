# Copyright:: (c) Autotelik Media Ltd 201=3
# Author ::   Tom Statter
# Date ::     Jan 2013
# License::   MIT. Free, Open Source.
#
# Details::   Helper tasks for setting up Royal Mail UK Shipping in Spree
#
# =>          N.B Before using set your required Rates(prices) in @cat_rates_matrix 

require 'thor'

module Datashift
  
  class DataBank < Thor
   
    desc "spree_uk_royal_mail", "Setup Royal Mail shipping"
  
    method_option :commit, :aliases => '-c', :type => :boolean, :required => false, :desc => "Commit changes permanently"
   
    def spree_uk_royal_mail 
    
      require File.expand_path('config/environment.rb')
           
      # Royal Mail is the ShippingMethod (actual service used to send the product) with 3 applicable Zones.
      #
      # [UK 1st, EU, INT]
      #
      # Matrix of Rates for  with your required Category(s)
      # Generally products are classified by ShippingCategory, with each Product assigned to a single Category
      # 
      # For example each Product could be in either of of these 2 Categories
      # @cat_rates_matrix = {
      #  'Light' => [3.73, 4.23, 5.95],
      #  'Heavy' => [5.00, 6.00, 10.00]
      # }
    
      @cat_rates_matrix = {
        'FlatPerOrder' => [10.00, 12.00, 15.00]
      }
      
      raise "Please set the Rates for each Categoryt in the task" if(@cat_rates_matrix.nil? || @cat_rates_matrix.empty?)
      
      Spree::Zone.transaction do

        #############################
        # Zone Setup for Royal Mail 
        #   http://www.royalmail.com
        #############################

        # FIRST CREATE 3 RM ZONES

        zone_map =  { 
          'UK' => 'United Kingdom (GB)', 
          'Europe' => 'Countries within the European economic area',
          'International' => 'Rest of World',
        }
      
        zone_names = zone_map.keys
      
        zone_map.each do |n, d|
          Spree::Zone.create( :name => n, :description => d )
        end

        # NOW POPULATE ZONE MEMBERS
      
        current_zone = Spree::Zone.find_by_name( 'UK' )
        country = Spree::Country.find_by_name( 'United Kingdom' )

        raise "No UK Zone/Country Found" unless current_zone && country

        # Seed on :zoneable_id since in this case we know each country in a distinct zone
        zoneable_type = 'Spree::Country'
      
        Spree::ZoneMember.create( :zone => current_zone, :zoneable_type => zoneable_type, :zoneable_id => country.id)

        ## 2 N.B This is for shipping FROM UK so UK NOT in Europe ZONE
        current_zone = Spree::Zone.find_by_name( 'Europe' )

        europe_list = %w{Albania Andorra Armenia Austria Azerbaijan Azores
      Balearic\ Islands
      Belarus Belgium
      Bosnia\ and\ Herzegovina
      Bulgaria
      Canary\ Islands
      Corsica Croatia Cyprus
      Czech\ Republic
      Denmark Estonia
      Faroe\ Islands
      Finland France Georgia Germany Gibraltar Greece Greenland Hungary Iceland
      Ireland
      Italy Kazakhstan Kosovo Kyrgyzstan Latvia Liechtenstein Lithuania Luxembourg
      Macedonia Madeira Malta 
      Moldova,\ Republic\ of
      Monaco Montenegro Netherlands Norway
      Poland Portugal Romania
      Russian\ Federation
      San\ Marino
      Serbia Slovakia Slovenia Spain Sweden Switzerland Tajikistan Turkey Turkmenistan
      Ukraine Uzbekistan
      Vatican\ City\ State
        }

        europe_list.each do |c|
  
          country = Spree::Country.find_by_name( c )

          unless country
            puts "WARNING: Country #{c} not found in DB - You will need to lookup ISO Codes to add"
          end

          Spree::ZoneMember.create( :zone => current_zone, :zoneable_type => zoneable_type, :zoneable_id => country.id)

        end

        current_zone = Spree::Zone.find_by_name( 'International' )

        raise "No International Zone Found" unless current_zone
      
        Spree::Country.all.each do |country|
                
          next if( country.name == 'United Kingdom' || europe_list.include?( country.name ) )

          Spree::ZoneMember.create!( :zone => current_zone, :zoneable_type => zoneable_type, :zoneable_id => country.id)
        end
          
        # In this example we are working with 1 deliverer, 4 Zones  => 4 Shipping Methods
        
        # And we have a single product classification => 1Shipping Categories:
        
        #######################
        # SHIPPING CATEGORIES #
        #######################

        #first create the categories
        @cat_rates_matrix.keys.each do |cat, rates|
        
          current_shipping_category = Spree::ShippingCategory.create :name => cat
      
          # Each Shipping Method associated with a single ZONE
      
          {  
            'Royal Mail UK 1st' => zone_names[0], 
            'Royal Mail Europe' => zone_names[1], 
            'Royal Mail International' => zone_names[2]
         
          }.each do |zone, name|
          
            ship_method_attributes = { :name => zone, :zone => Spree::Zone.find_by_name(name), 
              :shipping_category => current_shipping_category,
            }
          
            puts ship_method_attributes[:zone].inspect
          
          end
        end
        
            
        @calculators = Spree::ShippingMethod.calculators.sort_by(&:name)
      
        puts "Please Note - You now need to manually setup your required Calculators"
        puts "The curently available calculators : ", @calculators.join("\n")
        
        raise ActiveRecord::Rollback unless options[:commit] == true
     
      end
    end
  
  end
end