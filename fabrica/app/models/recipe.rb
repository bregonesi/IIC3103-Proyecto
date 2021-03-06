class Recipe < ApplicationRecord
  belongs_to :variant_product, class_name: 'Spree::Variant'
  belongs_to :variant_ingredient, class_name: 'Spree::Variant'

  validates :variant_product, presence: true
  validates :variant_ingredient, presence: true

  $cache_promedios_produccion = ActiveSupport::Cache::MemoryStore.new

  def self.promedios
    en_cache = $cache_promedios_produccion.read('cantidades')
    if !en_cache.nil?
      return en_cache
    end
  	cantidades = {}
  	Recipe.all.each do |r|
  		if cantidades[r.variant_ingredient.sku].nil?
  			cantidades[r.variant_ingredient.sku] = 0
  		end
  		cantidades[r.variant_ingredient.sku] += r.amount
  	end
  	cantidad_variants = Spree::Variant.where.not(sku: cantidades.keys).count
  	cantidades.each do |key, value|
  		cantidades[key] = value.to_f / cantidad_variants.to_f
  	end
    $cache_promedios_produccion.write('cantidades', cantidades)
  	cantidades
  end
end
