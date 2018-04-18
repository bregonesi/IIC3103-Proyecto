Spree::StockItem.class_eval do
  def count_on_hand
  	url = ENV['api_url'] + "bodega/skusWithStock"

		base = 'GET' + self.stock_location.admin_name
		key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

		r = RestClient::Request.execute(method: :get, url: url,
			headers: {
				params: {almacenId: self.stock_location.admin_name.to_s},
				'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key}
				)

		total = 0
		JSON.parse(r).each do |prod|
			if prod['_id'] == self.product.sku.to_s
				total += prod['total'].to_i
			end
		end

		return total
  end

  def count_on_hand2=(val)
  	raise jflkdsjlfk
  end
end

#Spree::StockItem.first.count_on_hand2