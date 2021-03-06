class CreateRecipes < ActiveRecord::Migration[5.1]
  def change
    create_table :recipes do |t|
      t.references :variant_product
      t.references :variant_ingredient
      t.integer :amount

      t.timestamps
    end

    add_index :recipes, :amount
    add_index :recipes, [:variant_product_id, :variant_ingredient_id], unique: true
  end
end
