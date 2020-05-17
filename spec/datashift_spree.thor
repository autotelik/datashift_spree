# Copyright:: (c) Autotelik B.V 2014
# Author ::   Tom Statter
# Date ::     June 2014
#
# License::   MIT - Free, OpenSource
#
# Details::   Spec tools for DatashiftSpree Gem
# 
#
require 'datashift'
require_relative 'sandbox_helper'

module Datashift
      
  class SpreeTasks < Thor  
  
    desc 'build_sandbox', 'Rebuild sandbox under spec for testing '

    def build_sandbox()
      

      DatashiftSpree::build_sandbox
      
      original_dir = Dir.pwd
      
      
      # TOFIX - this don't work ... but works if run straight after the task
      # maybe the env not right using system ?
      begin
        Dir.chdir DatashiftSpree::spree_sandbox_path
        puts "Running bundle install"
        system('bundle install')   
        
        puts "Running rake db:migrate"
        system('bundle exec rake db:migrate')     
      ensure
        Dir.chdir original_dir
      end
       
    end
  end
end
