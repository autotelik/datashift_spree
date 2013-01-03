# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Aug 2010
#
# License::   MIT - Free, OpenSource
#
# Details::   General tools related to DataShiftSpree Gem : specification, build, deploy
# 
#
module Datashift
      
  class SpreeTasks < Thor  
  
    desc 'build', 'Build gem '
  
    method_option :version, :required => true, :aliases => '-v', :desc => "YAML config containing static definitions"
    method_option :push, :aliases => '-p', :desc => "Push most recent gem to rubygems"
    method_option :install, :aliases => '-i', :desc => "Run gem install on the built gems"

    def build()

      $:.unshift '.'  # 1.9.3 quite strict, '.' must be in load path for relative paths to work from here

      gemspec = 'datashift_spree.gemspec'

      # Bump the VERSION file
   
      system("echo #{options[:version]} > VERSION ") if(options[:version])

      puts "Will build gem #{gemspec}"
      
      system("gem build #{gemspec}") 
       
      glob = options[:version] ? "datashift_spree-#{options[:version]}.gem" : "datashift_spree-*.gem"
    
      files = Dir[glob].sort_by { |f|File.mtime(f) }
      files.reject! { |f| (File.file?(f) ? false : true) }
      recent = files.reverse[0]
      
      if(options[:install] && recent)         
        puts recent
        system("gem install --no-ri --no-rdoc #{recent}")
      end
    
      if(options[:push] && recent) 
        system("gem push #{recent}")
      end
    end
  end
end