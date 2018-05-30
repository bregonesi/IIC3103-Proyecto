module Scheduler::ProductosHelper

	def mas_antiguo(stock_item)
		vencimiento_menor = ProductosApi.no_vencidos.where(stock_item: stock_item).order(:vencimiento).first
		return vencimiento_menor ? vencimiento_menor.vencimiento : Float::INFINITY
	end

	def obtener_lote_antiguo(stock_item, cantidad=nil)
		vencimiento_menor = mas_antiguo(stock_item)

		return ProductosApi.where(stock_item: stock_item, vencimiento: vencimiento_menor).limit(cantidad)
	end

	def mas_joven(stock_item)
		vencimiento_mayor = ProductosApi.no_vencidos.where(stock_item: stock_item).order(:vencimiento).last
		return vencimiento_mayor ? vencimiento_mayor.vencimiento : Time.at(0)
	end

	def obtener_lote_joven(stock_item, cantidad=nil)
		vencimiento_mayor = mas_joven(stock_item)

		return ProductosApi.where(stock_item: stock_item, vencimiento: vencimiento_mayor).limit(cantidad)
	end

	def hacer_movimientos
		puts "hanciendo movs"
		stop_scheduler = false
		Spree::StockMovement.where("originator_type = 'Spree::StockTransfer' AND quantity < 0 AND (-quantity > moved_quantity OR moved_quantity IS NULL)").each do |movement|
			movement.with_lock do
				puts "Ejecutando movement id " + movement.id.to_s

	      almacen_id_dest = nil
	      stock_item_dest = nil
			  Spree::StockMovement.where("originator_type = ? AND originator_id = ? AND quantity > 0", movement.originator_type, movement.originator_id).each do |movement_dest|
			  	puts "Movement destino id " + movement_dest.id.to_s
			  	almacen_id_dest = movement_dest.stock_item.stock_location.admin_name
			  	stock_item_dest = movement_dest.stock_item
			  end

				cargar_detalles(movement.stock_item)  ## por si aparecen nuevos stocks q agregar
				cargar_detalles(stock_item_dest)  ## por si aparecen nuevos stocks q agregar


				# buscaremos los productos (id) que moveremos
				if movement.stock_item.stock_location.proposito == "Despacho"  ## si es que saco de despacho, saco los jovenes y dejo los antiguos
					productos_mover = obtener_lote_joven(movement.stock_item, -movement.quantity.to_i - movement.moved_quantity.to_i)
				else
					productos_mover = obtener_lote_antiguo(movement.stock_item, -movement.quantity.to_i - movement.moved_quantity.to_i)
				end

	      j = 0
				productos_mover.each do |prod|  ## hay que mover producto por producto (si, ineficiente)
					prod.with_lock do 
					  # ahora hay que mover el prod_id encontrado
						url = ENV['api_url'] + "bodega/moveStock"
		  			base = 'POST' + prod.id_api.to_s + almacen_id_dest.to_s
		  			key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		  			r = HTTParty.post(url,
	  													body: {productoId: prod.id_api.to_s,
	  																 almacenId: almacen_id_dest.to_s}.to_json,
	  													headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
		  			
		  			if r.code == 200
		  				j += 1

							prod.stock_item = stock_item_dest  ## se movio de lugar
							prod.save!

		  				puts "Movimiento de un producto exitoso. Van " + j.to_s + " productos movidos."
		  			else
		          puts "Error movimiento productos. Error en response code de api. Responde code " + r.code.to_s + "."
		          if r.code == 404 || r.code == 400
		          	prod.destroy!
		          end
		        end
		      end
				end

				if movement.moved_quantity == nil
					movement.moved_quantity = 0
				end
				movement.moved_quantity += j
				movement.save!  ## actualizamos lo movido

				cargar_detalles(movement.stock_item)  ## por si aparecen nuevos stocks q agregar
				cargar_detalles(stock_item_dest)  ## por si aparecen nuevos stocks q agregar

				if movement.moved_quantity < -movement.quantity
					stop_scheduler = true
				end
			end
		end

		if stop_scheduler
			return hacer_movimientos
		end
	end

	def cargar_detalles(stock_item)
		variant = stock_item.variant
		almacen = stock_item.stock_location
		puts "Cargando detlles stock item " + stock_item.id.to_s + " y variant " + variant.sku.to_s + " almacen " + almacen.admin_name.to_s

		url = ENV['api_url'] + "bodega/stock"
	  base = 'GET' + almacen.admin_name + variant.sku
	  key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

	  r = HTTParty.get(url,
	                   query: {almacenId: almacen.admin_name.to_s,
	                   				 sku: variant.sku,
	                   				 limit: 200},
	                   headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
	  #puts r
			
		if r.code != 200
			raise "Error en get stock (detalle productos)"
		end

	  JSON.parse(r.body).each do |prod_api|
	  	new_producto = ProductosApi.where(id_api: prod_api['_id']).first_or_create! do |new_p|
	  		new_p.stock_item = stock_item
	  	end

	  	if new_producto
	  		new_producto.stock_item = stock_item
	  		new_producto.costo = prod_api['costo']
	  		new_producto.precio = prod_api['precio']
	  		new_producto.vencimiento = prod_api['vencimiento']

	  		new_producto.save!
	  	end
	  end
	end

	def cargar_nuevos  ## y elimina vencidos
		url = ENV['api_url'] + "bodega/skusWithStock"

		Spree::StockLocation.where.not(proposito: "Backorderable").each do |stock_location|
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
									cargar_detalles(stock_item)
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
