require 'rufus-scheduler'

puts "Partiendo scheduler"

job = Rufus::Scheduler.new

job.every '5m' do
  print "Ejecutando update.\n"

	# Aca pagamos las ordenes #
	Spree::Order.where(payment_state: "balance_due").each do |orden_inpaga|
		#if orden_inpaga.payments.first.number == "algo"  # aqui se chequea que coincide el pago
			#orden_inpaga.payment_state = "paid"
			orden_inpaga.payments.each do |orden_inpaga_pagos|
				orden_inpaga_pagos.send("capture!")  ## con esto se marca como pagado y se registra
			end
			# probablemente tengamos que llamar a la api del profe
			puts "Orden cambia a estado pagada"
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

      if r.code != 200
        raise "Error obteniendo productos en almacen " + inventario_para_despachar.shipment.stock_location.admin_name.to_s + "."
      end

      j = 0
			JSON.parse(r.body).each do |prod|  ## hay que eliminar producto por producto (si, ineficiente)
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
  				puts "Despacho de un producto exitoso."
  				j += 1
  			else
          puts "Error despachando orden. Error en response code de api. Responde code " + r.code.to_s + "."
        end
			end

			inventario_para_despachar.shipped_quantity += j
			inventario_para_despachar.save!  ## actualizamos lo despachado

			if inventario_para_despachar.shipped_quantity >= inventario_para_despachar.quantity
			  inventario_para_despachar.shipment.ship!
			  puts "Orden despachada"
			end
		end
	end

end

#scheduler.join
