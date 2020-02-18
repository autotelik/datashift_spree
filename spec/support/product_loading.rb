# Copyright:: (c) Autotelik B.V 2020
# Author ::   Tom Statter
# License::   MIT
#
# Details::   Spec Helpers/Shared examples for Spree Product Loading
#
RSpec.shared_context 'Populate dictionary ready for Product loading' do

  let(:product_klass) { ::Spree::Product }

  let(:image_klass) {  DataShiftSpree::get_spree_class 'Image' }

  config.before(:each) do
    DataShift::Configuration.reset
    DataShift::Exporters::Configuration.reset
    DataShift::Loaders::Configuration.reset
    DataShift::Transformation::Factory.reset
  end

  before do
    begin

      DataShift::ModelMethods::Catalogue.clear
      DataShift::ModelMethods::Manager.clear

    rescue => e
      puts e.inspect
      puts e.backtrace
      raise e
    end
  end
end
