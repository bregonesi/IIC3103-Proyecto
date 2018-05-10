class CreateRecipes < ActiveRecord::Migration[5.1]
  def change
    create_table :recipes do |t|
      t.string :sku
      t.string :ingredient_variant_sku
      t.integer :amount

      t.timestamps
    end
  end
end
