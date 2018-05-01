# Copyright:: (c) Autotelik Media Ltd 2016
# Author ::   Tom Statter
# Date ::     Aug 2016
# License::   MIT
#
# Details::   Spec Helpers/Shared examples for Spree Product Loading
#
RSpec.configure do |config|

  shared_context 'Populate dictionary ready for Product loading' do

    set_spree_class_helpers

    let(:product_klass) { Spree::Product }

    let(:image_klass) {  DataShift::SpreeEcom::get_spree_class 'Image' }

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

end
