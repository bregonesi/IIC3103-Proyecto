class AddAtencionToSpreeOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_orders, :atencion, :integer, default: 0
  end
end
