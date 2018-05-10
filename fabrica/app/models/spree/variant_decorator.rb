Spree::Variant.class_eval do
  has_many :recipes, foreign_key: 'sku', primary_key:'sku'
  has_many :ingredient_recipes, class_name: 'Recipe',
  foreign_key: 'ingredient_variant_sku', primary_key:'sku'

  def can_produce?
    self.ingredient_recipes.each do |ingredient|
      if Spree::Variant.find_by(sku: ingredient.ingredient_variant_sku).total_on_hand < amount
        return false
      end
    end
    
    return true
  end

end
