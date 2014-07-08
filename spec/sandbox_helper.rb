# Copyright:: (c) Autotelik Media Ltd 2014
# Author ::   Tom Statter
# Date ::     June 2014
# License::   MIT
#
# Details::   Helper for creating testing sandbox
#

puts File.expand_path("#{File.dirname(__FILE__)}/../lib")

$:.unshift File.expand_path("#{File.dirname(__FILE__)}/../lib")

require 'helpers/spree_helper'

module DataShift

  module SpreeHelper
    
    def self.run_in(dir)
      puts "Running cmd in [#{dir}]"
      original_dir = Dir.pwd
      begin
        Dir.chdir dir
        yield
      ensure
        Dir.chdir original_dir
      end
    end

    def self.spree_sandbox_name
      'rspec_spree_sandbox'
    end
    
    def self.spree_sandbox_path
      File.join(File.dirname(__FILE__), spree_sandbox_name)
    end
      
    def self.build_sandbox
      
      path = DataShift::SpreeHelper::spree_sandbox_path
      
      puts "Creating new Rails sandbox for Spree : #{path}"
      
      FileUtils::rm_rf(path) if(File.exists?(path))
            
      rails_sandbox_root = File.expand_path("#{path}/..")
         
      run_in(rails_sandbox_root)  do
        system('rails new ' + spree_sandbox_name)     
      end
      
      run_in(path)  do
        system("spree install --auto-accept") 
      end
      
      puts "Created Spree sandbox store : #{path}"
       
      # Now create a thor file for testing the CLI
      
      gem_string = "\n\n#RSPEC datashift-spree testing\ngem 'datashift_spree',  :path => \"#{File.expand_path(rails_sandbox_root + '/..')}\"\n"
      
      if(Gem.loaded_specs['datashift'])
       gem_string += "\ngem 'datashift', '#{Gem.loaded_specs['datashift'].version.version}'\n"
      else
        gem_string += "\ngem 'datashift'\n"
      end
       
      File.open("#{path}/Gemfile", 'a') { |f| f << gem_string }
      
      # Might need to add in User model if new 1.2 version which splits out Auth from spree core
      #
      #if(DataShift::SpreeHelper::version.to_f >= 1.2 || DataShift::SpreeHelper::version.to_f < 2 )
      #  File.open('Gemfile', 'a') { |f| f << "gem 'spree_auth_devise', :git => \"git://github.com/spree/spree_auth_devise\"\n" }
      #  end
            
      File.open("#{path}/spree_sandbox.thor", 'w') do |f| 
        thor_code = <<-EOS
        
require 'datashift'
require 'datashift_spree'

DataShift::SpreeHelper::load_commands
DataShift::load_commands
        EOS
        f << thor_code
      end
     
    end
  end
end