# Copyright:: (c) Autotelik B.V 2020
# Author ::   Tom Statter
#
# License::   MIT - Free, OpenSource
#
# Details::   Specification for Spree aspect of datashift gem.
#
#             Provides Loaders and rake tasks specifically tailored for uploading or exporting
#             Spree Products, associations and Images
#
require "rails_helper"

describe 'SpreeLoader' do
  
  include_context 'Populate dictionary ready for Product loading'
  
  # Operation and results should be identical when loading multiple associations
  # if using either single column embedded syntax, or one column per entry.

  it "should load Products and multiple Taxons from single column", :taxons => true do
    test_taxon_creation( 'SpreeProducts.xls' )
  end

  it "should load Products and multiple Taxons from multiple columns .xls", :taxons => true do
    test_taxon_creation( 'SpreeProductsMultiColumn.xls' )
  end

  it "should load Products and multiple Taxons from multiple columns CSV", :taxons => true do
    test_taxon_creation( 'SpreeProductsMultiColumn.csv' )
  end
  
  def test_taxon_creation( source )

    # we want to test both find and find_or_create so should already have an object
    # for find
    # want to test both lookup and dynamic creation - this Taxonomy should be found, rest created
    root = Spree::Taxonomy.create( :name => 'Paintings' )
    
    x = root.taxons.create( :name => 'Landscape')
    root.root.children << x
    
    expect(Spree::Taxonomy.count).to eq 1
    expect(Spree::Taxon.count).to eq 2

    expect(root.root.children.size).to eq 1
    expect(root.root.children[0].name).to eq 'Landscape'

    product_loader =  DatashiftSpree::ProductLoader.new(ifixture_file(source))

    product_loader.run
    
    expected_multi_column_taxons
  end
  
  def expected_multi_column_taxons

    # Paintings already existed and had 1 child Taxon (Landscape)
    # 2 nested Taxon (Paintings>Nature>Seascape) created under it so expect Taxonomy :
    
    # WaterColour	
    # Oils	
    # Paintings >Nature>Seascape + Paintings>Landscape	
    # Drawings
    
    expect(Spree::Taxonomy.all.collect(&:name).sort).to eq ["Drawings", "Oils", "Paintings", "WaterColour"]

    expect(Spree::Taxonomy.count).to eq 4
    expect(Spree::Taxon.count).to eq 7

    expect(Spree::Product.count).to eq 3
    
    p = @Variant_klass.where(sku: "DEMO_001").first.product

    expect(p.taxons.size).to eq 2
    expect(p.taxons.collect(&:name).sort).to eq ['Paintings','WaterColour']
     
    p2 = @Variant_klass.find_by_sku("DEMO_002").product

    expect(p2.taxons.size).to eq 4
    expect(p2.taxons.collect(&:name).sort).to eq ['Nature','Oils','Paintings','Seascape']
     
    paint_parent = Spree::Taxonomy.find_by_name('Paintings')

    expect(paint_parent.taxons.size).to eq 4 # 3 children + all Taxonomies have a root Taxon

    expect(paint_parent.taxons.collect(&:name).sort).to eq ['Landscape','Nature','Paintings','Seascape']
    
    tn = Spree::Taxon.find_by_name('Nature')    # child with children 
    ts = Spree::Taxon.find_by_name('Seascape')  # last child

    expect(ts).to_not be_nil
    expect(tn).to_not be_nil

    expect(p2.taxons.collect( &:id )).to include(ts.id)
    expect(p2.taxons.collect( &:id )).to include(tn.id)


    expect(tn.parent.id).to eq paint_parent.root.id
    expect(ts.parent.id).to eq tn.id

    expect(tn.children.size).to eq 1
    expect(ts.children.size).to eq 0
 
  end
  
  it "should load nested Taxons correctly even when same names from csv", :taxons => true do
    
    Spree::Taxonomy.delete_all
    Spree::Taxon.delete_all    
    
    expect(Spree::Taxonomy.count).to eq 0
    expect(Spree::Taxon.count).to eq 0

    expected_nested_multi_column_taxons 'SpreeProductsComplexTaxons.xls'
  end

  it "should load nested Taxons correctly even when same names from xls", :taxons => true do
    
    Spree::Taxonomy.delete_all
    Spree::Taxon.delete_all

    expect(Spree::Taxonomy.count).to eq 0
    expect(Spree::Taxon.count).to eq 0

    expected_nested_multi_column_taxons 'SpreeProductsComplexTaxons.csv'
  end
  
  def expected_nested_multi_column_taxons(source)

    product_loader = DatashiftSpree::ProductLoader.new(ifixture_file(source) )


    product_loader.run

    # Expected :
    # 2  Paintings>Landscape
    # 1  WaterColour
    # 1  Paintings
    # 1  Oils
    # 2  Drawings>Landscape            - test same name for child (Paintings)
    # 1  Paintings>Nature>Landscape    - test same name for child of a child
    # 1  Landscape	
    # 0  Drawings>Landscape                - test same structure should be reused
    # 2  Paintings>Nature>Seascape->Cliffs - test only the leaf node is created, rest re-used
    # 1  Drawings>Landscape>Bristol        - test a new leaf node created when parent name is same over different taxons
      
    puts Spree::Taxonomy.all.collect(&:name).sort.inspect
    expect(Spree::Taxonomy.count).to eq 5

    expect(Spree::Taxonomy.all.collect(&:name).sort).to eq ['Drawings', 'Landscape', 'Oils', 'Paintings','WaterColour']

    expect(Spree::Taxonomy.all.collect(&:root).collect(&:name).sort).to eq ['Drawings', 'Landscape', 'Oils', 'Paintings','WaterColour']
   
    taxons = Spree::Taxon.all.collect(&:name).sort
    
    #puts "#{taxons.inspect} (#{taxons.size})"

    expect(Spree::Taxon.count).to eq 12

    expect(taxons).to eq ['Bristol', 'Cliffs', 'Drawings', 'Landscape', 'Landscape', 'Landscape', 'Landscape', 'Nature', 'Oils', 'Paintings', 'Seascape','WaterColour']

    # drill down acts_as_nested_set ensure structures correct
    
    # Paintings - Landscape
    #           - Nature
    #                 - Landscape
    #                 - Seascape
    #                     - Cliffs
    painting_onomy = Spree::Taxonomy.find_by_name('Paintings')

    expect(painting_onomy.taxons.size).to eq 6
    painting_onomy.root.child?.should be false
     
    painting = painting_onomy.root

    expect(painting.children.size).to eq 2
    expect(painting.children.collect(&:name).sort).to eq ["Landscape", "Nature"]

    expect(painting.descendants.size).to eq 5
    
    lscape = {}
    nature = nil
    
    Spree::Taxon.each_with_level(painting.self_and_descendants) do |t, i|

      if(t.name == 'Nature')
        nature = t
        expect(i).to eq 1
        expect(t.children.size).to eq 2
        expect(t.children.collect(&:name)).to == ["Landscape", "Seascape"]

        expect(t.descendants.size).to eq 3
        expect(t.descendants.collect(&:name).sort).to == ["Cliffs", "Landscape", "Seascape"]
    
      elsif(t.name == 'Landscape')
        lscape[i] = t
      end
    end

    expect(nature).to_not be_nil

    expect(lscape.size).to eq 2
    expect(lscape[1].name).to eq 'Landscape'
    expect(lscape[1].parent.id).to eq painting.id

    expect(lscape[2].name).to eq 'Landscape'
    expect(lscape[2].parent.id).to eq nature.id
    
 
    seascape = Spree::Taxon.find_by_name('Seascape')
    expect(seascape.children.size).to eq 1
    expect(seascape.leaf?).to be false
    

    cliffs = Spree::Taxon.find_by_name('Cliffs')
    expect(cliffs.children.size).to eq 0
    expect(cliffs.leaf?).to be_truthy

    expect(Spree::Taxon.find_by_name('Seascape').ancestors.collect(&:name).sort).to eq ["Nature", "Paintings"]
    
    # Landscape appears multiple times, under different parents
    expect(Spree::Taxon.where( :name => 'Landscape').size).to eq 4

    # Check the correct Landscape used, Drawings>Landscape>Bristol
    
    drawings = Spree::Taxonomy.where(:name => 'Drawings').first

    expect(drawings.taxons.size).to eq 3
    
    dl = drawings.taxons.find_by_name('Landscape').children

    expect(dl.size).to eq 1
  
    b = dl.find_by_name('Bristol')

    expect(b.children.size).to eq 0
    expect(b.ancestors.collect(&:name).sort).to eq ["Drawings", "Landscape"]

    # empty top level taxons
    ['Oils', 'Landscape'].each do |t|
      tx = Spree::Taxonomy.find_by_name(t)
      expect(tx.taxons.size).to eq 1
      expect(tx.root.name).to eq t
      expect(tx.root.children.size).to eq 0
      expect(tx.root.leaf?).to be_truthy
    end

  end
  
end
