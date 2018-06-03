class FabricarRequest < ApplicationRecord
	belongs_to :sftp_order


  def can_produce?(lotes = 1)
  	variant = Spree::Variant.find_by(sku: self.sku)
  	variant.recipe.each do |ingredient|
  		cantidad_total = ingredient.variant_ingredient.cantidad_disponible + ingredient.amount
  		if cantidad_total < ingredient.amount * lotes
  			return false
  		end
  	end

  	return true
  end

  def self.por_recibir
    #FabricarRequest.where(aceptado: true, disponible: DateTime.now..Float::INFINITY)
    FabricarRequest.where(aceptado: true, disponible: DateTime.now.utc..Float::INFINITY)
  end

  def self.por_fabricar
    FabricarRequest.where(aceptado: false, razon: nil)
  end
end
