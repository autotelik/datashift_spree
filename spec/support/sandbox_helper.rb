# Copyright:: (c) Autotelik Media Ltd 2014
# Author ::   Tom Statter
# Date ::     June 2014
# License::   MIT
#
# Details::   Helper for creating testing sandbox
#

$:.unshift File.expand_path("#{File.dirname(__FILE__)}/../lib")

require 'datashift_spree'

module DataShift

  module SpreeEcom
    
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
      'dummy'
    end
    
    def self.spree_sandbox_path
      File.join(DatashiftSpreeLibraryBase, 'spec', spree_sandbox_name)
    end

    # The SPREE INSTALL COMMANDS based on current Gemfile Spree versions
    #
    # SEE  https://github.com/spree/spree#getting-started
    #
    def self.spree_install_cmds
      system("rails g spree:install --user_class=Spree::User --auto-accept --migrate --no-seed")
      system("rails g spree:auth:install")
      system("rails g spree_gateway:install")
    end

    def self.build_sandbox
      
      path = DataShift::SpreeEcom::spree_sandbox_path
      
      puts "Creating new Rails sandbox for Spree : #{path}"
      
      FileUtils::rm_rf(path) if(File.exists?(path))
            
      rails_sandbox_root = File.expand_path("#{path}/..")
         
      run_in(rails_sandbox_root)  do
        system('rails new ' + spree_sandbox_name)     
      end

      # ***** SPREE INSTALL COMMANDS ****

      run_in(path)  do
        spree_install_cmds
      end
      
      puts "Created Spree sandbox store : #{path}"
       
      # Now create a thor file for testing the CLI
      
      gem_string = "\n\n#RSPEC datashift-spree testing\ngem 'datashift_spree',  :path => \"#{File.expand_path(rails_sandbox_root + '/..')}\"\n"

      # TOFIX read this from ../Gemfile
      gem_string += "\ngem 'datashift', :git => 'https://github.com/autotelik/datashift.git', branch: :master\n"

      File.open("#{path}/Gemfile", 'a') { |f| f << gem_string }

      File.open("#{path}/spree_sandbox.thor", 'w') do |f| 
        thor_code = <<-EOS
        
require 'datashift'
require 'datashift_spree'

DataShift::SpreeEcom::load_commands
DataShift::load_commands
        EOS
        f << thor_code
      end
     
    end
  end
end
