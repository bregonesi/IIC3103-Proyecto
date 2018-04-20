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
  			#base = 'DELETE' + prod['_id'].to_s + inventario_para_despachar.shipment.address.address1 + inventario_para_despachar.line_item.price.to_i.to_s + inventario_para_despachar.order.number.to_s
  			base = 'DELETE' + prod['_id'].to_s + inventario_para_despachar.shipment.address.address1 + inventario_para_despachar.line_item.price.to_i.to_s
  			key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
  			r = HTTParty.delete(url,
  													body: {productoId: prod['_id'].to_s,
  																 direccion: inventario_para_despachar.shipment.address.address1,
  																 precio: inventario_para_despachar.line_item.price.to_i,
  																 #oc: inventario_para_despachar.order.number.to_s}.to_json,
  																 oc: ""}.to_json,
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

	# Chequeamos si tenemos nuevos almacenes o nos han eliminado alguno #
	url = ENV['api_url'] + "bodega/almacenes"

	base = 'GET'
	key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

	r = HTTParty.get(url, headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
	
	if r.code != 200
		raise "Error en get almacenes"
	end

	JSON.parse(r.body).each do |almacen|
	  almacen_q = Spree::StockLocation.find_by(admin_name: almacen['_id'].to_s)
	  if !almacen_q  ## si no existe
	  	puts "Se detecto un nuevo almacen. Almacen nuevo " + almacen['_id']
		  new_almacen = Spree::StockLocation.where(name: 'Almacen ' + (Spree::StockLocation.last.name.split(" ")[1].to_i + 1).to_s,
		                                           address1: 'Av. Vicuña Mackenna 4860',
		                                           city: 'Santiago',
		                                           zipcode: '7820436',
		                                           country: Spree::Country.find_by(iso: 'CL'),
		                                           state: Spree::Country.find_by(iso: 'CL').states.find_by(abbr: 'RM')
		                                          ).first_or_create! do |a_new|
	    	a_new.admin_name = almacen['_id']
	    end
		  if new_almacen
		    new_almacen.save
		  end
	  end
	end

  if JSON.parse(r.body).count != Spree::StockLocation.count  ## si nos eliminaron alguno
  	puts "Se detecto diferencias en cantidad de almacenes."
  	Spree::StockLocation.all.each do |stock_location|
  		encontrado = false
  		JSON.parse(r.body).each do |almacen|
  			if stock_location.admin_name == almacen['_id']  ## encontramos 
  				encontrado = true
  				break
  			end
  		end

  		if !encontrado
  			puts "Almacen " + stock_location.admin_name + " ya no existe."
  			stock_location.destroy
  		end
  	end
  end

  # Cargamos nuevos stocks y stock de almacenes nuevos #
	url = ENV['api_url'] + "bodega/skusWithStock"

	Spree::StockLocation.all.each do |stock_location|
	  base = 'GET' + stock_location.admin_name
	  key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

	  r = HTTParty.get(url,
	                   query: {almacenId: stock_location.admin_name.to_s},
	                   headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})

		if r.code != 200
			raise "Error en get stock"
		end

	  JSON.parse(r.body).each do |prod_api|
	    variant = Spree::Variant.find_by(sku: prod_api['_id'].to_s)
	    if variant
	    	stock_item = stock_location.stock_items.find_by(variant: variant)
	    	if stock_item
		      print "Variant sku: " + prod_api['_id'] + " encontrada.\n"

		      por_despachar = 0
		      stock_location.shipments.where(state: "ready").each do |prod_ship|  ## muestra todas las ordenes por despachar del stock location
		      	prod_ship.inventory_units.where(variant: variant, state: "on_hand").each do |iu|
		      		por_despachar += iu.quantity - iu.shipped_quantity
		      	end
		      end

		      diferencia = prod_api['total'].to_i - (stock_item.count_on_hand + por_despachar)
		      if diferencia != 0  # si no calza el stock, ie, se fabrico mas
						stock_movement = stock_location.stock_movements.build(quantity: diferencia.to_i)
						stock_movement.stock_item = stock_location.set_up_stock_item(variant)

						if stock_movement.save
							puts "Cargando stock para item sku: " + prod_api['_id'] + ", stock: " + diferencia.to_s + "."
						end
		      end

		    end

	    else
	      print "Variant sku: " + prod_api['_id'] + " no encontrada.\n"
	    end
	  end
	end

end

#job.join
