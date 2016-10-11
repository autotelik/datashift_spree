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
      system('rails g spree_digital:install --auto-run-migrations')
    end

    def self.build_sandbox

      spree_sandbox_path = DataShift::SpreeEcom::spree_sandbox_path

      puts "Creating new Rails sandbox for Spree : #{spree_sandbox_path}"

      FileUtils::rm_rf(spree_sandbox_path) if(File.exists?(spree_sandbox_path))

      rails_sandbox_root = File.expand_path("#{spree_sandbox_path}/..")

      run_in(rails_sandbox_root)  do
        system('rails new ' + spree_sandbox_name)
      end

      # Now add any gems required specifically for datashift_spree to the Gemfile

      gem_string = "\n\n#RSPEC datashift-spree testing\ngem 'datashift_spree',  :path => \"#{File.expand_path(rails_sandbox_root + '/..')}\"\n"

      gem_string += "\ngem 'datashift', :git => 'https://github.com/autotelik/datashift.git', branch: :master\n"

      gem_string += "\ngem 'spree_digital', github: 'spree-contrib/spree_digital', :branch => spree_version\n"

      File.open("#{spree_sandbox_path}/Gemfile", 'a') { |f| f << gem_string }

      # ***** SPREE INSTALL COMMANDS ****

      run_in(spree_sandbox_path)  do
        spree_install_cmds

      end

      puts "Created Spree sandbox store : #{spree_sandbox_path}"

      # Now create a thor file for testing the CLI

      File.open("#{spree_sandbox_path}/spree_sandbox.thor", 'w') do |f|
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
