class CreateReceta < ActiveRecord::Migration[5.1]
  def change
    create_table :receta do |t|
      t.integer :sku
      t.integer :variant_id_ingrediente
      t.integer :cantidad

      t.timestamps
    end
  end
end
