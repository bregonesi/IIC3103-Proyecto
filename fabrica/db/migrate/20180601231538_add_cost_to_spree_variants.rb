class AddCostoToSpreeVariants < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_variants, :costo, :integer, default: 0
  end
end
