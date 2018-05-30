class CreateSftpOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :sftp_orders do |t|
      t.string :oc
      t.string :cliente
      t.string :proveedor
      t.string :sku
      t.datetime :fechaEntrega
      t.integer :cantidad
      t.integer :myCantidadDespachada
      t.integer :serverCantidadDespachada
      t.integer :precioUnitario
      t.string :canal
      t.text :notas
      t.text :rechazo
      t.text :anulacion
      t.string :urlNotificacion
      t.string :myEstado
      t.string :serverEstado

      t.timestamps
    end
  end
end
