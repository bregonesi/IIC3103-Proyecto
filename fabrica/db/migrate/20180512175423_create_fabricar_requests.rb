class CreateFabricarRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :fabricar_requests do |t|
      t.string :id_prod
      t.string :sku
      t.string :grupo
      t.datetime :disponible
      t.integer :cantidad
      t.boolean :aceptado
      t.references :sftp_order

      t.timestamps
    end
  end
end
