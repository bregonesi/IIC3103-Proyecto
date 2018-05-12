class AddLoteMinimoToSpreeVariants < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_variants, :lote_minimo, :integer, default: 0
  end
end
