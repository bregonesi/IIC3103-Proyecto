Spree::Variant.class_eval do
  has_many :recipe, class_name: 'Recipe', foreign_key: 'variant_product_id'	
  has_many :ingredients, through: :recipe, source: :variant_ingredient

  has_many :passive_ingredient, class_name: 'Recipe', foreign_key: 'variant_ingredient_id'	
  has_many :variant_master, through: :passive_ingredient, source: :variant_product

  def primary?
    #self.recipe.empty?  ## no es lo mas correcto, pero en este caso sirve
    ["20", "30", "40", "50", "60", "70"].include?(self.sku)
  end

  def can_produce?(lotes = 1)
  	self.recipe.each do |ingredient|
  		if !ingredient.variant_ingredient.can_ship?(ingredient.amount * lotes)
  			return false
  		end
  	end

  	return true
  end

  def can_ship?(cantidad_minima = 1)
    return cantidad_disponible >= cantidad_minima
  end

  def cantidad_disponible
    cantidad_disponible = self.total_on_hand
    FabricarRequest.por_fabricar.each do |request|
      ingrediente = Spree::Variant.find_by(sku: request.sku).recipe.find_by(variant_ingredient_id: self)
      if ingrediente
        cantidad_disponible -= ingrediente.amount
      end
    end

    return cantidad_disponible
  end
end
