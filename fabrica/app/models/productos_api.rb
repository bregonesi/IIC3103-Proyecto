class ProductosApi < ApplicationRecord
	belongs_to :stock_item, class_name: 'Spree::StockItem'

	def readonly?  ## si ya vencio no lo tocamos mas
		return self.vencimiento && Time.now() >= self.vencimiento  # si time es mayor q vencimiento, entnces aun es valido
	end
end
