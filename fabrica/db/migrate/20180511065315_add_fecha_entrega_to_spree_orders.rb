class AddFechaEntregaToSpreeOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_orders, :fechaEntrega, :datetime
    add_index :spree_orders, :fechaEntrega
  end
end
