class ApiController < ApplicationController
	def stock_publico
		productos = Spree::Product.all

		json_p = []
		productos.each do |product|
			json_p << {:sku => product.sku.to_s, :available => product.stock.to_i}
		end

		render json: json_p, :status => 200
	end

	def stock_privado
    pattern = /^Bearer /
    header  = request.headers['Authorization']
    key = header.gsub(pattern, '') if header && header.match(pattern)

		json_p = []

    if(key == "hola")

			productos = Spree::Product.all

			productos.each do |product|
				json_p << {:sku => product.sku.to_s, :available => product.stock.to_i}
			end

			render json: json_p, :status => 200
		else 
			json_p << {:error => "Token malo"}
			render json: json_p, :status => 401
		end

	end
end
