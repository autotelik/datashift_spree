# This migration comes from spree_digital (originally 20111207121840)
class RenameDigitalToNamespace < SpreeExtension::Migration[4.2]
  def change
    rename_table :digitals, :spree_digitals
    rename_table :digital_links, :spree_digital_links
  end
end
