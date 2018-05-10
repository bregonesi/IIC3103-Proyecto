class ValidadorCapacidad < ActiveModel::Validator
  def validate(record)
    if record.quantity > record.stock_item.stock_location.available_capacity
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