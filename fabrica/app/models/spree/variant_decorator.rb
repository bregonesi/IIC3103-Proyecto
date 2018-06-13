Spree::Variant.class_eval do
  has_many :recipe, class_name: 'Recipe', foreign_key: 'variant_product_id'	
  has_many :ingredients, through: :recipe, source: :variant_ingredient

  has_many :passive_ingredient, class_name: 'Recipe', foreign_key: 'variant_ingredient_id'	
  has_many :variant_master, through: :passive_ingredient, source: :variant_product

  $cache_variant = ActiveSupport::Cache::MemoryStore.new(expires_in: 10.seconds)

  def primary?
    #self.recipe.empty?  ## no es lo mas correcto, pero en este caso sirve
    ["20", "30", "40", "50", "60", "70"].include?(self.sku)
  end

  def can_produce?(lotes = 1)
    if self.primary?
      return false
    end
    
  	self.recipe.each do |ingredient|
  		if !ingredient.variant_ingredient.can_ship?(ingredient.amount * lotes)
  			return false
  		end
  	end

  	return true
  end

  def materias_faltantes_producir(lotes = 1)
    if self.primary?
      return []
    end
    
    faltante = {}
    self.recipe.each do |ingredient|
      if !ingredient.variant_ingredient.can_ship?(ingredient.amount * lotes)
        faltante[ingredient.variant_ingredient.sku] = ingredient.amount * lotes - ingredient.variant_ingredient.cantidad_disponible
      end
    end

    return faltante
  end

  def can_ship?(cantidad_minima = 1)
    return cantidad_disponible >= cantidad_minima
  end

  def cantidad_disponible
    cantidad_disponible = self.total_on_hand
    FabricarRequest.por_fabricar.each do |request|
      ingrediente = Spree::Variant.find_by(sku: request.sku).recipe.find_by(variant_ingredient_id: self)
      if !ingrediente.nil?
        cantidad_disponible -= ingrediente.amount
      end
    end

    return cantidad_disponible
  end

  def por_necesitar
    ## influye para materias prima
    ## retorno cuanto necesitare de materia prima en las ordenes preaceptadas
    a_necesitar = 0
    SftpOrder.preaceptadas.each do |sftp_order|
      variant = Spree::Variant.find_by(sku: sftp_order.sku)
      cantidad_en_fabricacion = (sftp_order.fabricar_requests.por_recibir + sftp_order.fabricar_requests.por_fabricar).map(&:cantidad).reduce(:+).to_i
      cantidad_faltante = sftp_order.faltante - cantidad_en_fabricacion
      cantidad_faltante = [cantidad_faltante, 0].max
      lotes_restantes = (cantidad_faltante.to_f / variant.lote_minimo.to_f).ceil
      ingrediente = variant.recipe.find_by(variant_ingredient: self)
      if !ingrediente.nil?
        a_necesitar += ingrediente.amount * lotes_restantes
      end
    end

    ## ahora veo si me llegaron productos y aun no despacho
    (SftpOrder.aceptadas.where(sku: self.sku) + SftpOrder.preaceptadas.where(sku: self.sku)).each do |sftp_order|
      a_necesitar += sftp_order.faltante
    end
    a_necesitar
  end

  def cantidad_api
    en_cache = $cache_variant.read(['cantidad_api', self.id])
    if !en_cache.nil?
      return en_cache
    end

    promedios = Recipe.promedios
    cantidad = [self.cantidad_disponible.to_i - self.por_necesitar.to_i - promedios[self.sku.to_s].to_i * 3, 0].max
    
    $cache_variant.write(['cantidad_api', self.id], cantidad)
    return cantidad
  end
end
