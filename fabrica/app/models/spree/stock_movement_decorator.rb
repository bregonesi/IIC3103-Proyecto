class ValidadorCapacidad < ActiveModel::Validator
  def validate(record)
    if record.quantity > 0 && record.quantity > record.stock_item.stock_location.available_capacity && !(record.action == "Diferencia de stock con bodega." || record.originator_type == "Spree::Shipment")
      record.errors[:base] << "Excede maximo de capacidad (" + record.quantity.to_s + " > " + record.stock_item.stock_location.available_capacity.to_s + ")"
    end
  end
end

Spree::StockMovement.class_eval do
	validates_with ValidadorCapacidad

  def readonly?
    false
  end
end