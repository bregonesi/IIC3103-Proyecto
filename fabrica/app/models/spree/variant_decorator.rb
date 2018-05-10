Spree::Variant.class_eval do
  has_many :recipes, foreign_key: 'sku', primary_key:'sku'
  has_many :ingredient_recipes, class_name: 'Recipe',
  foreign_key: 'ingredient_variant_sku', primary_key:'sku'

  def can_produce?
    self.recipes.each do |recipe|
      ingredient = Spree::Variant.find_by(sku: recipe.ingredient_variant_sku)
      if ingredient.total_on_hand < recipe.amount
        return false
      end
    end

    return true
  end

end
