module Scheduler::ProductosHelper

	def hacer_movimientos
		stop_scheduler = false
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
	end

	def cargar_nuevos  ## y elimina vencidos
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
		    		stock_item.with_lock do
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

			    end
		    else
		      print "Variant sku: " + prod_api['_id'] + " no encontrada.\n"
		    end
		  end

	    variants_eliminar = Spree::Variant.where.not(sku: skus_en_stock)
	    variants_eliminar.each do |variant|
	    	stock_item = stock_location.stock_items.find_by(variant: variant)
	    	if stock_item
	    		stock_item.with_lock do
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
	    end
		  
		end # end de actualizar stock
	end

end