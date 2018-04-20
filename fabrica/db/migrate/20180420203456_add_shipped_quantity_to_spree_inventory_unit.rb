class AddShippedQuantityToSpreeInventoryUnit < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_inventory_units, :shipped_quantity, :int, null: false, default: 0
  end
end
