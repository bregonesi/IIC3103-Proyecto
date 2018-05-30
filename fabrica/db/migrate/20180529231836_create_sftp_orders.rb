class CreateSftpOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :sftp_orders do |t|
      t.string :oc
      t.string :sku
      t.integer :quantity
      t.string :cliente
      t.string :proveedor
      t.datetime :fechaEntrega
      t.string :canal
      t.string :urlNotificacion
      t.string :myEstado
      t.string :serverEstado

      t.timestamps
    end
  end
end
