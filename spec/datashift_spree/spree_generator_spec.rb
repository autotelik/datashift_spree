# Copyright:: (c) Autotelik Media Ltd 2011
# Author ::   Tom Statter
# Date ::     Summer 2011
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for Spree generator aspect of datashift gem.
#
#             Provides Loaders and rake tasks specifically tailored for uploading or exporting
#             Spree Products, associations and Images
#
require "spec_helper"

require 'excel_generator'

module DataShift


  describe 'SpreeGenerator' do

    before(:all) do
    end

    before do
      # Create some test data
      root = @Taxonomy_klass.create( :name => 'Paintings' )

      if(DataShift::SpreeEcom::version.to_f > 1 )
        root.taxons.create( :name => 'Landscape' )
        root.taxons.create( :name => 'Sea' )
      else
        @Taxon_klass.create( :name => 'Landscape', :taxonomy => root )
        @Taxon_klass.create( :name => 'Sea', :taxonomy => root )
      end
    end

    it "should export any Spree model to .xls spreedsheet" do

      expected = result_file('taxonomy_export_spec.xls')

      excel = DataShift::ExcelGenerator.new

      excel.generate(expected, @Taxonomy_klass)

      expect(File.exists?(expected)).to eq true

      puts "You can check results manually in file #{expected}"

      expected = result_file('taxon_export_spec.xls')

      excel.file_name = expected

      excel.generate(expected, @Taxon_klass)

      expect(File.exists?(expected)).to eq true

      puts "You can check results manually in file #{expected}"

    end

    it "should export Spree Product and all associations to .xls spreedsheet" do

      expected = result_file('product_and_assoc_export_spec.xls')

      excel = DataShift::ExcelGenerator.new

      excel.generate_with_associations(expected, Spree::Product)

      expect(File.exists?(expected)).to eq true

      excel = Excel.new
      excel.open(expected)

      expect(excel.worksheets.size).to eq 1

      expect(excel.worksheet(0).name).to eq Spree::Product.name

      headers = excel.worksheets[0].row(0)

      expect(headers).to include(*Spree::Product.columns.collect(&:name))
    end
  end
end
