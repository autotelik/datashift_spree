require 'spree'
require 'spree_core'

module DatashiftSpree
  class Engine < ::Rails::Engine
    isolate_namespace DatashiftSpree
  end
end
