class AddCantidadPedidaToOcRequest < ActiveRecord::Migration[5.1]
  def change
    add_column :oc_requests, :cantidad_pedida, :integer, default: 0
  end
end
