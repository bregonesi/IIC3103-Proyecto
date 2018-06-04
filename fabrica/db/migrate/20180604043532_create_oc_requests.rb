class CreateOcRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :oc_requests do |t|
      t.references :sftp_order, foreign_key: true
      t.string :sku
      t.integer :cantidad
      t.boolean :por_responder, default: true
      t.boolean :aceptado, default: false
      t.boolean :despachado, default: false

      t.timestamps
    end
  end
end
