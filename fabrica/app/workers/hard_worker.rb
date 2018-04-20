require 'httparty'

class HardWorker
  include Sidekiq::Worker

  def perform(*args)

  	# Aca pagamos las ordenes #
  	Spree::Order.where(payment_state: "balance_due").each do |orden_inpaga|
  		#if orden_inpaga.payments.first.number == "algo"  # aqui se chequea que coincide el pago
  			#orden_inpaga.payment_state = "paid"
  			orden_inpaga.payments.each do |orden_inpaga_pagos|
  				orden_inpaga_pagos.send("capture!")  ## con esto se marca como pagado y se registra
  			end
  			# probablemente tengamos que llamar a la api
  			puts "Orden cambia a estado pagada"
  			#orden_inpaga.save
  		# end
  	end

  	# Aca despachamos lo pagado #
		url = ENV['api_url'] + "bodega/stock"
  	Spree::InventoryUnit.where(state: "on_hand", pending: "f").each do |inventario_para_despachar|
  		if inventario_para_despachar.order.payment_state == "paid"  ## hay que pagar primero

  			# buscaremos los productos (id) que mandaremos
  			base = 'GET' + inventario_para_despachar.shipment.stock_location.admin_name.to_s + inventario_para_despachar.variant.sku.to_s
  			key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
  			r = HTTParty.get(url,
  											 query: {almacenId: inventario_para_despachar.shipment.stock_location.admin_name.to_s,
  											 				 sku: inventario_para_despachar.variant.sku.to_s,
  											 				 limit: inventario_para_despachar.quantity.to_i},
  											 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
				# lo ideal seria que el request anterior lo ordene por fecha de vencimiento de producto

  			#inventario_para_despachar.quantity.times do |i|  ## hay que eliminar producto por producto (si, ineficiente)
  			puts "antes del json"
  			JSON.parse(r.body).each do |prod|
  				puts "despues del json"
  				puts prod
				  # ahora hay que eliminar el prod_id encontrado
	  			base = 'DELETE' + prod['_id'].to_s + inventario_para_despachar.shipment.address.address1 + inventario_para_despachar.line_item.price.to_i.to_s + inventario_para_despachar.order.number.to_s
	  			key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
	  			r = HTTParty.delete(url,
	  													body: {productoId: prod['_id'].to_s,
	  																 direccion: inventario_para_despachar.shipment.address.address1,
	  																 precio: inventario_para_despachar.line_item.price.to_i,
	  																 oc: inventario_para_despachar.order.number.to_s}.to_json,
	  													headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
	  			
	  			if r.code == 200
	  				puts "exito"
	  			end

				end

				# if todos salieron con exito
				puts inventario_para_despachar.shipment.ship!
				puts "Orden despachada"
				# end del if

  		end
  	end

  end

end
