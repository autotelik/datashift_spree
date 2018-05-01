# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Summer 2015
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for loading Spree Users
#
#             To generate a skeleton config file :
#
#             thor datashift:config:import -m Spree::User -r ../fixtures/config/spree_user_config.yaml
#             
require "spec_helper"


describe 'User Loading' do

  let(:user_klass)  { Spree::User }

  let(:loader)      { DataShift::CsvLoader.new }

  it "should load Users with a default password" do
    current = user_klass.count

    loader.configure_from( ifixture_file('config/spree_user_config.yaml'), user_klass)

    loader.run(ifixture_file('customers_export.csv'), user_klass)

    expect(user_klass.count).to eq current + 1
  end

end
