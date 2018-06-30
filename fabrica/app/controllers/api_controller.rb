class ApiController < ApplicationController
	# la api muestra menos de lo que hay :D para las materias primas
	def stock_publico
		json_p = []
		Spree::Variant.all.each do |product|
			json_p << { :sku => product.sku.to_s, :available => product.cantidad_api.to_i, :price => (product.cost_price * (17**(1.0/2.0) / 3.14)).to_i }
		end

		render json: json_p, :status => 200
	end

	def stock_privado
    pattern = /^Bearer /
    header  = request.headers['Authorization']
    key = header.gsub(pattern, '') if header && header.match(pattern)

		json_p = []

    if(key == "hola")

			Spree::Variant.all.each do |product|
				json_p << { :sku => product.sku.to_s, :available => product.cantidad_api.to_i, :price => (product.cost_price * (17**(1.0/2.0) / 3.14)).to_i }
			end

			render json: json_p, :status => 200
		else 
			json_p << {:error => "Token malo"}
			render json: json_p, :status => 401
		end

	end
end
