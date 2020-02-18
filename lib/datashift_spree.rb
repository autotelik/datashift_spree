# Copyright:: (c) Autotelik B.V 2020
# Author ::   Tom Statter
# License::   MIT, Free, Open Source.
#
# Details:: Spree Product and Image Loader from .xls or CSV
#
require 'datashift'

module DatashiftSpree

  def self.root_path
    File.expand_path("#{File.dirname(__FILE__)}/..")
  end

  def self.library_path
    File.expand_path("#{File.dirname(__FILE__)}/../lib")
  end

  # Load all the datashift rake tasks and make them available throughout app
  def self.load_tasks
    # Long parameter lists so ensure rake -T produces nice wide output
    ENV['RAKE_COLUMNS'] = '180'
    base = File.join(root_path, 'tasks', '**')
    Dir["#{base}/*.rake"].sort.each { |ext| load ext }
  end

  # Load all public datashift spree Thor commands and make them available throughout app

  def self.load_commands
    base = File.join(library_path, 'thor')
    Dir["#{base}/**/*.thor"].each do |f|
      next unless File.file?(f)
      Thor::Util.load_thorfile(f)
    end
  end

end

Gem.find_files('datashift_spree/**/*.rb').each { |path| require path }
