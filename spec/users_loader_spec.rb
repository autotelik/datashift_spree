# Copyright:: (c) Autotelik Media Ltd 2015
# Author ::   Tom Statter
# Date ::     Summer 2015
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for loading Spree Users
#
#             
require File.join(File.expand_path(File.dirname(__FILE__) ), "spec_helper")


describe 'User Loading' do

  let(:user_klass)  { Spree::User }

  let(:loader)      { DataShift::CsvLoader.new(user_klass) }

  it "should load Users with a default password" do

    current = user_klass.count

    loader.configure_from( ifixture_file('config/SpreeUserDefaults.yml') )

    loader.perform_load( ifixture_file('customers_export.csv') )

    expect(user_klass.count).to eq current + 1

  end

end
