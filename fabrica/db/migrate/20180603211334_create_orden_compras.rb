class CreateOrdenCompras < ActiveRecord::Migration[5.1]
  def change
    create_table :orden_compras do |t|
      t.integer :_id
      t.string :cliente
      t.string :proveedor
      t.string :sku
      t.datetime :fechaEntrega
      t.integer :cantidad
      t.integer :cantidadDespachada
      t.integer :precioUnitario
      t.string :canal
      t.string :estado
      t.string :notas
      t.string :rechazo
      t.string :anulacion
      t.string :urlNotificacion
      t.datetime :created_at
      t.datetime :updated_at

      t.timestamps
    end
  end
end
