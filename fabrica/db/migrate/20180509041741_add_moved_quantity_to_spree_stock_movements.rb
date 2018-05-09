class AddMovedQuantityToSpreeStockMovements < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_stock_movements, :moved_quantity, :integer
  end
end
