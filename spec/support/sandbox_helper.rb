# Copyright:: (c) Autotelik B.V 2020
# Author ::   Tom Statter
# License::   MIT
#
# Details::   Helper for creating a Spree store in a Rails engine 'dummy' sandbox
#
module DatashiftSpree

  class Sandbox

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
      @spree_sandbox_path ||= File.expand_path( File.join(File.dirname(__FILE__), '../', spree_sandbox_name) )
    end

    def self.installed_flag_file
      "#{spree_sandbox_path}/spree_sandbox_installed.txt"
    end

    def self.flag_installed
      File.open(installed_flag_file, 'w') { |f| f << Time.now.to_s }
    end

    def self.installed?
      File.exists?(installed_flag_file)
    end

    # The SPREE INSTALL COMMANDS based on current Gemfile Spree versions
    #
    # SEE  https://github.com/spree/spree#getting-started
    #
    def self.spree_install_cmds
      system("bundle exec rails g spree:install --force --user_class=Spree::User --sample=false --seed=false --copy_storefront=false")
      system("bundle exec rails g spree:auth:install")
      system("bundle exec rails g spree_gateway:install")

        #system('rails g spree_digital:install --auto-run-migrations')
    end

    def self.install_spree

      pp File.exists?(installed_flag_file)

      return if installed?

      puts "Creating new Spree store in Rails sandbox : #{spree_sandbox_path}"

      run_in(spree_sandbox_path) do
        system("bundle install")
      end

      run_in(spree_sandbox_path) do
        puts "Running SPREE INSTALLATION"
        spree_install_cmds
      end

      puts "Created Spree sandbox store : #{spree_sandbox_path}"

      # Now create a thor file for testing the CLI

      File.open("#{spree_sandbox_path}/spree_sandbox.thor", 'w') do |f|
        thor_code = <<-EOS
        
require 'datashift'
require 'datashift_spree'

DatashiftSpree::load_commands
DataShift::load_commands
        EOS
        f << thor_code
      end

      flag_installed

    end
  end

end
