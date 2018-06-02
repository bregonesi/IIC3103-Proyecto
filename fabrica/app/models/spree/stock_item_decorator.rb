Spree::StockItem.class_eval do
  has_many :productos_api

  #scope :with_active_stock_location, -> { joins(:stock_location) }  ## forzamos a desactivar esto
  def waiting_factory_units  ## los primeros 5 minutos desde que se produce queda pegado el espacio del profe
  	if self.stock_location.proposito != "Despacho"
  		return 0
  	end

    retenido = 0
    #FabricarRequest.por_recibir.where(disponible: DateTime.now..5.minutes.from_now).each do |fr|
    #last_despacho_time = Spree::InventoryUnit.where(state: "shipped").order(updated_at: :desc).first.updated_at
    FabricarRequest.por_recibir.where(disponible: DateTime.now..2.hours.from_now).each do |fr|
      variant = Spree::Variant.find_by(sku: fr.sku)
      ingrediente = variant.recipe.find_by(variant_ingredient: self.variant)
      if !ingrediente.nil?
        retenido += ingrediente.amount
      end
    end
    retenido
  end
end