Spree::Stock::Quantifier.class_eval do
  def can_supply?(required = 1)
  	caller_locations.each do |c|
  		strr = c.to_s
  		if strr.include?("html.erb") || strr.include?("spree_frontend")
  			puts "Front end"
  			return variant.available? && (variant.cantidad_api >= required || backorderable?)
  		end
  	end

    variant.available? && (total_on_hand >= required || backorderable?)
  end

end