# Copyright:: (c) Autotelik Media Ltd 2012
# Author ::   Tom Statter
# Date ::     March 2012
# License::   MIT. Free, Open Source.
#
# Usage::
# bundle exec thor help datashift:spree
# bundle exec thor datashift:spree:products -i db/datashift/MegamanFozz20111115_load.xls -s 299S_
#
# bundle exec thor  datashift:spree:images -i db/datashift/imagebank -s -p 299S_
#

# Note, not DataShift, case sensitive, create namespace for command line : datashift

require 'spree'

require 'datashift_spree'

require 'spree_ecom'

module DatashiftSpree 
  
  class Load < Thor

    include DataShift::Logging

    desc "products", "Populate Spree Product/Variant data from .xls (Excel) or CSV file"

    method_option :input, :aliases => '-i', :required => true, :desc => "The import file (.xls or .csv)"
    method_option :sku_prefix, :aliases => '-s', :desc => "Prefix to add to each SKU before saving Product"
    method_option :image_path_prefix, :aliases => '-p', :desc => "Prefix to add to image path for importing from disk"
    method_option :verbose, :aliases => '-v', :type => :boolean, :desc => "Verbose logging"
    method_option :config, :aliases => '-c',  :type => :string, :desc => "Configuration file containg defaults or over rides in YAML"
    method_option :dummy, :aliases => '-d', :type => :boolean, :desc => "Dummy run, do not actually save Image or Product"

    def products()

      # TODO - We're assuming run from a rails app/top level dir...
      # ...can we make this more robust ? e.g what about when using active record but not in Rails app,
      require File.expand_path('config/environment.rb')

      input = options[:input]

      require 'product_loader'

      loader = DataShift::SpreeEcom::ProductLoader.new( nil, {:verbose => options[:verbose]})

      # YAML configuration file to drive defaults etc

      if(options[:config])
        raise "Bad Config - Cannot find specified file #{options[:config]}" unless File.exists?(options[:config])

        puts "DataShift::Product proccssing config from: #{options[:config]}"

        loader.configure_from( options[:config] )
      else
        loader.populator.set_default_value('available_on', Time.now.to_s(:db) )
        loader.populator.set_default_value('cost_price', 0.0 )
        loader.populator.set_default_value('price', 0.0 )
      end

      loader.set_prefix('sku', options[:sku_prefix] ) if(options[:sku_prefix])

      puts "DataShift::Product starting upload from file: #{input}"

      opts = options.dup
      opts[:mandatory] = ['sku', 'name', 'price']

      loader.perform_load(input, opts)
    end


    desc "attach_images", "Populate Products with images from Excel/CSV\nProvide column SKU or Name\nColumn containing full path to image can be named 'attachment', 'images' or 'path' "
    # :dummy => dummy run without actual saving to DB
    method_option :input, :aliases => '-i', :required => true, :desc => "The 2 column import file (.xls or .csv)"

    def attach_images()

      require File.expand_path('config/environment.rb')

      require 'image_loader'

      loader = DataShift::SpreeEcom::ImageLoader.new(nil, options)

      loader.perform_load( options[:input], options )
    end


    # => thor datashift:spree:images input=vendor/extensions/site/fixtures/images
    #
    desc "images", "Populate the DB with images from a directory
    The image name, must contain the Product Sku somewhere within it.

    N.B Currently only lookup on SKU available - more flexability coming soon"

    method_option :input, :aliases => '-i', :required => true, :desc => "The input path containing images "

    method_option :glob, :aliases => '-g',  :desc => 'The glob to use to find files e.g. \'{*.jpg,*.gif,*.png}\' '
    method_option :recursive, :aliases => '-r', :type => :boolean, :desc => "Scan sub directories of input for images"

    method_option :find_by_field, :desc => "TODO - Find Variant/Product based on any field"

    method_option :sku_prefix, :aliases => '-s', :desc => "SKU prefix to add to each image name before attempting Product lookup"
    method_option :dummy, :aliases => '-d', :type => :boolean, :desc => "Dummy run, do not actually save Image or Product"

    method_option :process_when_no_assoc, :aliases => '-f', :type => :boolean, :desc => "Process image even if no Product found - force loading"
    method_option :skip_when_assoc, :aliases => '-x', :type => :boolean, :desc => "DO not process image if Product already has image"

    method_option :verbose, :aliases => '-v', :type => :boolean, :desc => "Verbose logging"
    method_option :config, :aliases => '-c',  :type => :string, :desc => "Configuration file for Image Loader in YAML"

    method_option :split_file_name_on,  :type => :string, :desc => "delimiter to progressivley split filename for Prod lookup", :default => "_"
    method_option :case_sensitive, :type => :boolean, :desc => "Use case sensitive where clause to find Product"
    method_option :use_like, :type => :boolean, :desc => "Use sku/name LIKE 'string%' instead of sku/name = 'string' in where clauses to find Product"

    def images()

      @attachment_path = options[:input]

      unless(File.exists?(@attachment_path))
        puts "ERROR: Supplied Path [#{@attachment_path}] not accesible"
        exit(-1)
      end

      require File.expand_path('config/environment.rb')

      require 'paperclip/attachment_loader'

      image_klass = DataShift::SpreeEcom::get_spree_class('Image' )

      raise "Cannot find suitable Paperclip Attachment Class" unless image_klass

      loader_options = { :verbose => true }

      owner_klass = DataShift::SpreeEcom::product_attachment_klazz

      loader_options[:attach_to_klass] = owner_klass    # Pass in real Ruby class not string class name

      # WTF  ... this works in the specs but thor gives me
      # products_images.thor:131:in `images': uninitialized constant Thor::Sandbox::Datashift::Spree::Variant (NameError)
      # loader_options[:attach_to_find_by_field] = (owner_klass. == Spree::Variant) ? :sku : :name

      # so for now just sku lookup available .... TOFIX - name wont currently work for Variant and sku won't work for Product
      # so need  way to build a where clause or add scopes to Variant/Product

      loader_options[:attach_to_find_by_field] = :sku

      loader_options[:attach_to_field] = 'images'

      loader = DataShift::Paperclip::AttachmentLoader.new(image_klass, nil, loader_options)

      logger.info "Loading attachments from #{@attachment_path}"

      attach_options = options.dup
      attach_options[:add_prefix] = options[:sku_prefix]

      puts "Setting prefix to [#{attach_options[:add_prefix]}]"

      loader.process_from_filesystem(@attachment_path, attach_options.dup)

    end

  end
end