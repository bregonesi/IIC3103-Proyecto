class CreateProductosApis < ActiveRecord::Migration[5.1]
  def change
    create_table :productos_apis do |t|
      t.string :id_api
      t.references :stock_item
      t.integer :costo
      t.integer :precio
      t.datetime :vencimiento

      t.timestamps
    end

    add_index :productos_apis, :costo
    add_index :productos_apis, :precio
    add_index :productos_apis, :vencimiento
  end
end
