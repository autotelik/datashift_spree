# Copyright:: (c) Autotelik Media Ltd 201=3
# Author ::   Tom Statter
# Date ::     Jan 2013
# License::   MIT. Free, Open Source.
#
# Details::   Helper tasks for setting up Royal Mail UK Shipping in Spree
#
#             Must be run from your Rails.root path
#             
# =>          N.B Before using set your required Rates(prices) in @cat_rates_matrix 

require 'thor'


module DatashiftSpree
  
  module DataBank
    
    class UkShipping < Thor
   
      #############################
      # Zone Setup for Royal Mail 
      #   http://www.royalmail.com
      #############################
    
      @@usage =<<-EOS
Setup Spree with Royal Mail Zones, Shipping Categories and Methods

Shipping methoid requires a CalculatorType 

To list currently Available Calculators run with --list
      EOS
  
      desc "royal_mail", @@usage                    
             
      method_option :commit, :aliases => '-c', :type => :boolean, :required => false, :desc => "Commit changes permanently"
      method_option :calc, :required => false, :default =>  'Spree::Calculator::FlatRate', :desc => "Calculators"
      method_option :list, :required => false, :desc => "List available Calculators and exit"
   
      def royal_mail 
        require File.expand_path('config/environment.rb')
   
        if options[:list]
          puts "Available Calculators are:"
          puts "\t#{Spree::ShippingMethod.calculators.sort_by(&:name).join("\n\t")}"

          puts "\nSpecify with --calc"
          exit(0)
        end
        # Royal Mail is the ShippingMethod (actual service used to send the product) with 3 applicable Zones.
        #
        # [UK 1st, EU, INT]
        #
        # Matrix of Rates for  with your required Category(s)
        # Generally products are classified by ShippingCategory, with each Product assigned to a single Category
        # 
        # For example each Product would be in either one of the Categories, Light or Heavy
        # @cat_rates_matrix = {
        #  'Light' => [3.73, 4.23, 5.95],
        #  'Heavy' => [5.00, 6.00, 10.00]
        # }
    
        @cat_rates_matrix = {
          'FlatPerOrder' => [10.00, 12.00, 15.00]
        }
      
        raise "Please set the Rates for each Categoryt in the task" if(@cat_rates_matrix.nil? || @cat_rates_matrix.empty?)
      
        Spree::Zone.transaction do

          # FIRST CREATE 3 RM ZONES

          zone_map =  { 
            'UK' => 'United Kingdom (GB)', 
            'Europe' => 'Countries within the European economic area',
            'International' => 'Rest of World',
          }
      
          zone_names = zone_map.keys
      
          zone_map.each do |n, d|
            Spree::Zone.create( :name => n, :description => d )
            puts "Zone #{n} created"
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
              puts "WARNING: Country #{c} not found in DB"
              puts "If you require this Country #{c} you will have to add MANUALLY with ISO"
              next
            end

            Spree::ZoneMember.create!( :zone => current_zone, :zoneable_type => zoneable_type, :zoneable_id => country.id)
          end
                
          puts "European countries added to Europe Zone"
            
          current_zone = Spree::Zone.find_by_name( 'International' )

          raise "No International Zone Found" unless current_zone
      
          Spree::Country.all.each do |country|
                
            next if( country.name == 'United Kingdom' || europe_list.include?( country.name ) )

            Spree::ZoneMember.create!( :zone => current_zone, :zoneable_type => zoneable_type, :zoneable_id => country.id)
          end
          
          puts "Countries added to International Zone"
                    
          # In this example we are working with 1 deliverer, 3 Zones  => 3 Shipping Methods
        
          # And we have a single product classification => 1 Shipping Categories:
        
          #######################
          # SHIPPING CATEGORIES #
          #######################

          #first create the categories
          @cat_rates_matrix.each do |cat, rates|
        
            current_shipping_category = Spree::ShippingCategory.create!(:name => cat)
      
            puts "Spree::ShippingCategory #{cat} created"
             
            # Now associate Shipping   with Zones
            @shipping_methods = []
            {  
              'Royal Mail UK 1st' => zone_names[0], 
              'Royal Mail Europe' => zone_names[1], 
              'Royal Mail International' => zone_names[2]
         
            }.each do |name, zone|
          
              ship_method_attributes = { 
                :name => name, 
                :zone => Spree::Zone.find_by_name(zone), 
                :shipping_category => current_shipping_category,
                :calculator_type => options[:calc]
              }
              
              @shipping_methods << Spree::ShippingMethod.create!( ship_method_attributes, :without_protection => true )  
              
              puts "Spree::Shipping Method #{name} created with Cal #{options[:calc]} in Zone #{zone}"    
            end
            
            # Now set the Rates (
            unless(@shipping_methods.size == rates.size)
              puts "WARNING: Sorry could not set Rates check @cat_rates_matrix set correctly in script" 
            else
              puts "Setting Rates on the Shipping Methods" 
              @shipping_methods.each_with_index do |m, i| 
                m.calculator.preferred_amount= rates[i]; 
                m.save! 
              end
            end
          end      
          
          unless options[:commit] == true  
            puts "Dummy run - rolling back changes - run with --commit to make changes permenant"
            raise ActiveRecord::Rollback 
          end
        end
      end
  
      desc "counties", "Setup UK Counties (Spree::State)"
  
      method_option :commit, :aliases => '-c', :type => :boolean, :required => false, :desc => "Commit changes permanently"
   
      def counties
             
        require File.expand_path('config/environment.rb')
        
        names, abbrs = [],[]

        names << 'Avon'
        names << 'Bedfordshire'
        names << 'Berkshire'
        names << 'Borders'
        names << 'Buckinghamshire'
        names << 'Cambridgeshire'
        names << 'Central'
        names << 'Cheshire'
        names << 'Cleveland'
        names << 'Clwyd'
        names << 'Cornwall'
        names << 'County Antrim'
        names << 'County Armagh'
        names << 'County Down'
        names << 'County Fermanagh'
        names << 'County Londonderry'
        names << 'County Tyrone'
        names << 'Cumbria'
        names << 'Derbyshire'
        names << 'Devon'
        names << 'Dorset'
        names << 'Dumfries and Galloway'
        names << 'Durham'
        names << 'Dyfed'
        names << 'East Sussex'
        names << 'Essex'
        names << 'Fife'
        names << 'Gloucestershire'
        names << 'Grampian'
        names << 'Greater Manchester'
        names << 'Gwent'
        names << 'Gwynedd County'
        names << 'Hampshire'
        names << 'Herefordshire'
        names << 'Hertfordshire'
        names << 'Highlands and Islands'
        names << 'Humberside'
        names << 'Isle of Wight'
        names << 'Kent'
        names << 'Lancashire'
        names << 'Leicestershire'
        names << 'Lincolnshire'
        names << 'London'
        names << 'Lothian'
        names << 'Merseyside'
        names << 'Mid Glamorgan'
        names << 'Norfolk'
        names << 'North Yorkshire'
        names << 'Northamptonshire'
        names << 'Northumberland'
        names << 'Nottinghamshire'
        names << 'Oxfordshire'
        names << 'Powys'
        names << 'Rutland'
        names << 'Shropshire'
        names << 'Somerset'
        names << 'South Glamorgan'
        names << 'South Yorkshire'
        names << 'Staffordshire'
        names << 'Strathclyde'
        names << 'Suffolk'
        names << 'Surrey'
        names << 'Tayside'
        names << 'Tyne and Wear'
        names << 'Warwickshire'
        names << 'West Glamorgan'
        names << 'West Midlands'
        names << 'West Sussex'
        names << 'West Yorkshire'
        names << 'Wiltshire'
        names << 'Worcestershire'

        uk = Spree::Country.find_by_name( 'United Kingdom' )

        names.each do |n|
          Spree::State.create( :name => n, :country_id => uk.id)
        end
      end
    
    end
  end # class

end # module