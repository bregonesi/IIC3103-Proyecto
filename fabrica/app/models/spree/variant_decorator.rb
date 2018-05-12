Spree::Variant.class_eval do
  has_many :recipe, class_name: 'Recipe', foreign_key: 'variant_product_id'	
  has_many :ingredients, through: :recipe, source: :variant_ingredient

  has_many :passive_ingredient, class_name: 'Recipe', foreign_key: 'variant_ingredient_id'	
  has_many :variant_master, through: :passive_ingredient, source: :variant_product

  def can_produce?(lotes = 1)
  	self.recipe.each do |ingredient|
  		if ingredient.variant_ingredient.total_on_hand < ingredient.amount*lotes
  			return false
  		end
  	end

  	return true
  end
end
