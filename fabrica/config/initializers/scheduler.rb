require 'rufus-scheduler'


if defined?(::Rails::Server) || File.basename($0) =='rake'
	puts "Partiendo scheduler"

	job = Rufus::Scheduler.new(:max_work_threads => 1)

	job.every '35s' do
	  print "Ejecutando update.\n"
	  stop_scheduler = false

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
	  				j += 1
	  				puts "Despacho de un producto exitoso. Van " + j.to_s + " productos despachados."
	  			else
	          puts "Error despachando orden. Error en response code de api. Responde code " + r.code.to_s + "."
	        end
				end

				inventario_para_despachar.shipped_quantity += j
				inventario_para_despachar.save!  ## actualizamos lo despachado

				if inventario_para_despachar.shipped_quantity >= inventario_para_despachar.quantity
				  inventario_para_despachar.shipment.ship!
				  puts "Orden despachada"
				else
					stop_scheduler = true
				end

				if stop_scheduler
					raise "Botamos aproposito para que no siga ejecutanto"
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

		# Aca movemos los items de almacen #
		Spree::StockMovement.where("originator_type = 'Spree::StockTransfer' AND quantity < 0 AND (-quantity > moved_quantity OR moved_quantity IS NULL)").each do |movement|
			movement.with_lock do
				# buscaremos los productos (id) que moveremos
				almacen_id = movement.stock_item.stock_location.admin_name
				sku_movement = movement.stock_item.variant.sku
				url = ENV['api_url'] + "bodega/stock"
				base = 'GET' + almacen_id.to_s + sku_movement.to_s
				key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
				r = HTTParty.get(url,
												 query: {almacenId: almacen_id.to_s,
												 				 sku: sku_movement.to_s,
												 				 limit: -movement.quantity.to_i - movement.moved_quantity.to_i},
												 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
				# lo ideal seria que el request anterior lo ordene por fecha de vencimiento de producto

	      if r.code != 200
	        raise "Error obteniendo productos en almacen " + almacen_id.to_s + "."
	      end

	      almacen_id_dest = nil
			  Spree::StockMovement.where("originator_type = ? AND originator_id = ? AND quantity > 0", movement.originator_type, movement.originator_id).each do |movement_dest|
			  	almacen_id_dest = movement_dest.stock_item.stock_location.admin_name
			  end

	      j = 0
				JSON.parse(r.body).each do |prod|  ## hay que mover producto por producto (si, ineficiente)
				  # ahora hay que mover el prod_id encontrado
					url = ENV['api_url'] + "bodega/moveStock"
	  			base = 'POST' + prod['_id'].to_s + almacen_id_dest.to_s
	  			key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
	  			r = HTTParty.post(url,
	  													body: {productoId: prod['_id'].to_s,
	  																 almacenId: almacen_id_dest.to_s}.to_json,
	  													headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
	  			
	  			if r.code == 200
	  				j += 1
	  				puts "Movimiento de un producto exitoso. Van " + j.to_s + " productos movidos."
	  			else
	          puts "Error movimiento orden. Error en response code de api. Responde code " + r.code.to_s + "."
	        end
				end

				if movement.moved_quantity == nil
					movement.moved_quantity = 0
				end
				movement.moved_quantity += j
				movement.save!  ## actualizamos lo movido

				if movement.moved_quantity < -movement.quantity
					stop_scheduler = true
				end
			end

			if stop_scheduler
				raise "Botamos aproposito para que no siga ejecutanto"
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

			skus_en_stock = []
		  JSON.parse(r.body).each do |prod_api|
				skus_en_stock << prod_api['_id'].to_s  # los agrego por que despues los sku que estan en la tabla pero no en esta lista se vencieron

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
							stock_movement.action = "Diferencia de stock con bodega."
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

	    variants_eliminar = Spree::Variant.where.not(sku: skus_en_stock)
	    variants_eliminar.each do |variant|
	    	stock_item = stock_location.stock_items.find_by(variant: variant)
	    	if stock_item
	    		if stock_item.count_on_hand > 0
						stock_movement = stock_location.stock_movements.build(quantity: -(stock_item.count_on_hand.to_i))
						stock_movement.action = "Eliminado por vencimiento (o desaparecio de bodega)."
						stock_movement.stock_item = stock_location.set_up_stock_item(variant)
						if stock_movement.save
	    				puts "Se marca " + variant.sku + " como vencido."
						end
	    		end
	    	end
	    end
		  
		end # end de actualizar stock

	end # end del scheduler

	#job.join
end