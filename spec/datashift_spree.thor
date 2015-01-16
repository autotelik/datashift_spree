# Copyright:: (c) Autotelik Media Ltd 2014
# Author ::   Tom Statter
# Date ::     June 2014
#
# License::   MIT - Free, OpenSource
#
# Details::   Spec tools for DataShiftSpree Gem
# 
#
module Datashift
      
  class SpreeTasks < Thor  
  
    desc 'build_sandbox', 'Rebuild sandbox under spec for testing '

    def build_sandbox()
      
      $:.unshift '.'
      
      require 'datashift'
      require 'sandbox_helper'
     
      DataShift::SpreeEcom::build_sandbox
      
      original_dir = Dir.pwd
      
      
      # TOFIX - this don't work ... but works if run straight after the task
      # maybe the env not right using system ?
      begin
        Dir.chdir DataShift::SpreeEcom::spree_sandbox_path
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