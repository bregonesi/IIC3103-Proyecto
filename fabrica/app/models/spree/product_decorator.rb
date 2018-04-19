Spree::Product.class_eval do
  def can_supply?
  	self.stock_items.each do |stock_item|
  		if stock_item.count_on_hand != 0  # apenas se detecte uno entonces se corta
  			return true
  		end
  	end

		return false
  end

  def stock
  	stock_t = 0

  	self.stock_items.each do |stock_item|
  		stock_t += stock_item.count_on_hand
  	end

  	return stock_t
  end
end
