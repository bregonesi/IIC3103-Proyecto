class AddInfoAlmacenToSpreeStockLocations < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_stock_locations, :proposito, :string
    add_column :spree_stock_locations, :capacidad_maxima, :integer

    add_index :spree_stock_locations, :proposito
  end
end
