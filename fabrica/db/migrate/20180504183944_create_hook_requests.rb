class CreateHookRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :hook_requests do |t|
      t.string :sku
      t.integer :cantidad
      t.datetime :disponible
      t.integer :ip
      t.boolean :aceptado
      t.text :razon

      t.timestamps
    end
  end
end
