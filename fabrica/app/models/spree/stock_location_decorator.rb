Spree::StockLocation.class_eval do
  def used_capacity
  	used = 0
    
    self.stock_items.each do |item|
    	used += item.count_on_hand
    end

    return used
  end

  def available_capacity
  	self.capacidad_maxima - used_capacity
  end

  def self.almacenes
    Spree::StockLocation.where(proposito: ["Recepcion", "Despacho", "Pulmon", "General"])
  end
end