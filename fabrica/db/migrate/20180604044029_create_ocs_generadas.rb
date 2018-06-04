class CreateOcsGeneradas < ActiveRecord::Migration[5.1]
  def change
    create_table :ocs_generadas do |t|
      t.references :oc_request, foreign_key: true
      t.string :oc_id
      t.integer :grupo
      t.string :cliente
      t.string :proveedor
      t.string :sku
      t.datetime :fechaEntrega
      t.integer :cantidad
      t.integer :precioUnitario
      t.string :canal
      t.string :notas
      t.string :urlNotificacion

      t.timestamps
    end
  end
end
