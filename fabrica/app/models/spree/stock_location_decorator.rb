Spree::StockLocation.class_eval do
  def items_capacity
    self.stock_items.sum(:count_on_hand)
  end

  def shipment_capacity
    items_por_despachar = 0
    self.shipments.each do |shipment|
      if shipment.order.completed?
        shipment.inventory_units.each do |iu|
          items_por_despachar = iu.quantity - iu.shipped_quantity
        end
      end
    end
    items_por_despachar
  end

  def in_factory
    self.stock_items.sum(&:waiting_factory_units)
    #FabricarRequest.por_recibir.count * 100
  end

  def used_capacity
    items_capacity + shipment_capacity + in_factory
  end

  def available_capacity
  	self.capacidad_maxima - used_capacity
  end

  def self.almacenes
    Spree::StockLocation.where(proposito: ["Recepcion", "Despacho", "Pulmon", "General"])
  end

  def self.recepciones
    Spree::StockLocation.where(proposito: "Recepcion")
  end

  def self.despachos
    Spree::StockLocation.where(proposito: "Despacho")
  end

  def self.pulmones
    Spree::StockLocation.where(proposito: "Pulmon")
  end

  def self.generales
    Spree::StockLocation.where(proposito: "General")
  end
end