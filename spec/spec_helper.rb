# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Aug 2011
# License::   MIT
#
# Details::   Spec Helper for Active Record Loader
#
#
# We are not setup as a Rails project so need to mimic an active record database setup so
# we have some  AR models to test against. Create an in memory database from scratch.
#
require 'active_record'
require 'thor/actions'
require 'bundler'
require 'stringio'

require 'datashift'
require 'datashift_spree'

require 'spree_helper'

 
RSpec.configure do |config|
  config.before do
    ARGV.replace []
  end

  include Thor::Actions 
    
  def run_in(dir )
    puts "RSpec .. running test in path [#{dir}]"
    original_dir = Dir.pwd
    begin
      Dir.chdir dir
      yield
    ensure
      Dir.chdir original_dir
    end
  end
  
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  alias :silence :capture  
  
  def fixtures_path()
    File.expand_path(File.dirname(__FILE__) + '/fixtures')
  end
  
  def ifixture_file( name )
    File.join(fixtures_path(), name)
  end
  
  def results_path
    File.join(fixtures_path(), 'results')
  end
  
  def spree_negative_fixture_path
    File.join(fixtures_path, 'negative')   
  end
  
  def self.spree_fixture( source)
    ifixture(source)
  end
  
  def bundler_setup(gemfile)
    ENV['BUNDLE_GEMFILE'] = gemfile

    begin
      Bundler.setup(:default, :development)
    rescue Bundler::BundlerError => e
      $stderr.puts e.message
      $stderr.puts "Run `bundle install` to install missing gems"
      exit e.status_code
    end
  end
  
  # SPREE
  def spree_sandbox_path
    File.join(File.dirname(__FILE__), 'sandbox')
  end
      
  def before_all_spree 
  
    puts "SET", File.expand_path(File.dirname(__FILE__)) + '/Gemfile'
    
    bundler_setup( File.expand_path(File.dirname(__FILE__)) + '/Gemfile')
    
    # We are not a Spree project, so we implement a spree application of our own
    # 
    if(DataShift::SpreeHelper::is_namespace_version )
      spree_boot
    else
      RSpecSpreeHelper::boot('test_spree_standalone')             # key to YAML db e.g  test_memory, test_mysql
    end
    
    puts "Testing Spree standalone - version #{DataShift::SpreeHelper::version}"

    set_spree_class_helpers
    
  end
  
  def before_each_spree
      
    # Reset main tables - TODO should really purge properly, or roll back a transaction      
    @Product_klass.delete_all
    
    @spree_klass_list.each do |k| z = DataShift::SpreeHelper::get_spree_class(k); 
      if(z.nil?)
        puts "WARNING: Failed to find expected Spree CLASS #{k}" 
      else
        DataShift::SpreeHelper::get_spree_class(k).delete_all 
      end
    end
  end
  
  def set_logger( name = 'datashift_spree_spec.log')
    
    require 'logger'
    logdir = File.dirname(__FILE__) + '/logs'
    FileUtils.mkdir_p(logdir) unless File.exists?(logdir)
    ActiveRecord::Base.logger = Logger.new( File.join(logdir, name) )

    # Anyway to direct one logger to another ????? ... Logger.new(STDOUT)
    
    @dslog = ActiveRecord::Base.logger
  end
   
  # Datashift is usually included and tasks pulled in by a parent/host application.
  # So here we are hacking our way around the fact that datashift is not a Rails/Spree app/engine
  # so that we can ** run our specs ** directly in datashift library
  # i.e without ever having to install datashift in a host application
  #
  # NOTES:
  # => Will chdir into the sandbox to load environment as need to mimic being at root of a rails project
  #    chdir back after environment loaded
    
  def spree_boot()
    puts "def spree_boot()", spree_sandbox_path
    ActiveRecord::Base.clear_active_connections!() 

    spree_sandbox_app_path = spree_sandbox_path
        
    unless(File.exists?(spree_sandbox_app_path))
      puts "Creating new Rails sandbox for Spree : #{spree_sandbox_app_path}"
      
      run_in(File.expand_path( "#{spree_sandbox_app_path}/..")) {
        system('rails new sandbox')
      }
      
      run_in(spree_sandbox_app_path) {
        system('spree install')      
      
        # add in User model if new 1.2 version which splits out Auth from spree core
        if(DataShift::SpreeHelper::version.to_f >= 1.2)
          append_file('Gemfile', "gem 'spree_auth_devise', :git => \"git://github.com/spree/spree_auth_devise\"" )
          
          system('bundle install')   
        end
      }
    end
  
    puts "Using Rails sandbox for Spree : #{spree_sandbox_app_path}"
        
    run_in(spree_sandbox_app_path) {
                  
      begin
        require 'config/environment.rb'
      rescue => e
        #somethign in deface seems to blow up suddenly on 1.1
        puts "Warning - Potential issue initializing Spree sandbox:"
        puts e.backtrace
        puts "#{e.inspect}"
      end
        
      set_logger( 'spree_sandbox.log' )
        
    }
        
    @dslog.info "Booted Spree using version #{DataShift::SpreeHelper::version}"
  end
  
  include Thor::Actions 
      
  def set_spree_class_helpers
    @spree_klass_list  =  %w{Image OptionType OptionValue Property ProductProperty Variant Taxon Taxonomy Zone}
    
    @Product_klass = DataShift::SpreeHelper::get_product_class  
  
    @spree_klass_list.each do |k|
      instance_variable_set("@#{k}_klass", DataShift::SpreeHelper::get_spree_class(k)) 
    end
  end
  
  def self.boot( database_env)
  
    ActiveRecord::Base.clear_active_connections!() 
      
    unless(DataShift::SpreeHelper::is_namespace_version)
        
      DataShift::SpreeHelper::load() 
        
      db_connect( database_env )
      @dslog.info "Booting Spree using pre 1.0.0 version"
      boot_pre_1
      @dslog.info "Booted Spree using pre 1.0.0 version"
                
      RSpecSpreeHelper::migrate_up      # create an sqlite Spree database on the fly
    end
  end

  def self.boot_pre_1
 
    require 'rake'
    require 'rubygems/package_task'
    require 'thor/group'

    require 'spree_core/preferences/model_hooks'
    #
    # Initialize preference system
    ActiveRecord::Base.class_eval do
      include Spree::Preferences
      include Spree::Preferences::ModelHooks
    end
 
    gem 'paperclip'
    gem 'nested_set'

    require 'nested_set'
    require 'paperclip'
    require 'acts_as_list'

    CollectiveIdea::Acts::NestedSet::Railtie.extend_active_record
    ActiveRecord::Base.send(:include, Paperclip::Glue)

    gem 'activemerchant'
    require 'active_merchant'
    require 'active_merchant/billing/gateway'

    ActiveRecord::Base.send(:include, ActiveMerchant::Billing)
  
    require 'scopes'
    
    # Not sure how Rails manages this seems lots of circular dependencies so
    # keep trying stuff till no more errors
    
    Dir[lib_root + '/*.rb'].each do |r|
      begin
        require r if File.file?(r)  
      rescue => e
      end
    end

    Dir[lib_root + '/**/*.rb'].each do |r|
      begin
        require r if File.file?(r) && ! r.include?('testing')  && ! r.include?('generators')
      rescue => e
      end
    end
    
    load_models( true )

    Dir[lib_root + '/*.rb'].each do |r|
      begin
        require r if File.file?(r)  
      rescue => e
      end
    end

    Dir[lib_root + '/**/*.rb'].each do |r|
      begin
        require r if File.file?(r) && ! r.include?('testing')  && ! r.include?('generators')
      rescue => e
      end
    end

    #  require 'lib/product_filters'
     
    load_models( true )

  end
  
  def self.load_models( report_errors = nil )
    puts 'Loading Spree models from', DataShift::SpreeHelper::root
    Dir[DataShift::SpreeHelper::root + '/app/models/**/*.rb'].each {|r|
      begin
        require r if File.file?(r)
      rescue => e
        puts("WARNING failed to load #{r}", e.inspect) if(report_errors == true)
      end
    }
  end

  def self.migrate_up
    ActiveRecord::Migrator.up( File.join(DataShift::SpreeHelper::root, 'db/migrate') )
  end

end