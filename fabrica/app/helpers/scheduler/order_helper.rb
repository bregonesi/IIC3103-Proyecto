module Scheduler::OrderHelper

	def marcar_vencidas
		Spree::Order.where("fechaEntrega <= ?", DateTime.now).where.not(state: "canceled").each do |order|
			r = HTTParty.post(ENV['api_oc_url'] + "rechazar/" + order.number.to_s, body: {}.to_json, headers: { 'Content-type': 'application/json' })
			order.canceled_by(Spree::User.first)  ## el primero se supone que es el admin
		end
	end

	def aceptar_ordenes
		##
		## Una orden tiene mas o menos 24 horas para ser acepta. Voy a analizar si
		## acepto fabricar dentro de las 16 horas pasadas (osea, que le queden 8 horas)
		## para caducar. Esto por que la fabricacion toma a veces 12 horas.
		## Fabrico hasta tres lotes maximos (mando uno a uno)
		##
		## Si son dos o menos lotes y tengo stock acepto de inmediato
		##
		## A las ordenes caducan en menos de 8 horas le despacho solo si tengo para satisfacer
		## la mitad o mas de lo que le falta (siempre deberia ser a lo mas una orden que se encuentra asi)
		##
		## Cuando le quedan 1 hora o menos para que caduque una orden puede que le despache
		## eso depende de si los productos que me piden se me vencen dentro de 6 horas o si es
		## cubro toda su demanda
		##

		## aqui veo si tengo stock de alguna orden y tiene menos de dos lotes
		Spree::Order.where(state: "complete", channel: "ftp", payment_state: "paid").where.not(atencion: 2).each do |orden|
			orden.with_lock do
				se_completa = true
				orden.inventory_units.each do |iu|
					variant = iu.variant
					lotes = BigDecimal((iu.quantity.to_f/variant.lote_minimo.to_f).to_s).ceil

					if variant.total_on_hand < iu.quantity || lotes > 2
						se_completa = false
					end
				end
				
				if se_completa
					url = ENV['api_oc_url'] + "recepcionar/"
	  			r = HTTParty.post(url + orden.number.to_s, body: {}.to_json, headers: { 'Content-type': 'application/json' })
	  			
	  			if r.code != 200
	  				raise "Error en recepcionar oc"
	  			end

					orden.inventory_units.each do |iu|
						iu.with_lock do
							# cambiamos los prod al almacen de despacho
							cambiar_items_a_despacho(Spree::Variant.find(iu.variant.id), iu.quantity.to_i)

							# cambiamos el shipment de backorder a almacen de despacho
							Spree::Shipment.find(iu.shipment.id).transfer_to_location(
																											Spree::Variant.find(iu.variant.id),
																											iu.quantity.to_i,
																											Spree::StockLocation.where(proposito: "Despacho").first)
							orden.atencion = 2
							orden.save!
						end
					end
				end

			end
		end

		ordenes = []  # [orden, costo_un_lote, lotes, costo_total]
		ordenes_query = Spree::Order.where(state: "complete", channel: "ftp", payment_state: "paid", shipment_state: "backorder", atencion: 0).where("fechaEntrega >= ?", 16.hours.ago).each do |order|
			order.inventory_units.each do |iu|
				variant = iu.variant

				costo = variant.ingredients.sum(:lote_minimo)  ## llamamos costo a la cantidad de productos que hay que utilizar

				costo_lote = variant.lote_minimo
				lotes = BigDecimal((iu.quantity.to_f/variant.lote_minimo.to_f).to_s).ceil
				ordenes << [order, costo_lote, lotes, costo_lote * lotes]
			end
		end

		ordenes = ordenes.sort_by{ |i| i[1] }  ## primero ordeno por costo de un lote
		ordenes = ordenes.sort_by{ |i| i[3] }  ## despues ordeno por costo total
		# asi va a quedar mas importante costo total

		#puts ordenes

		j = 0
		while Spree::Order.where(atencion: 1).count < (ordenes_query.count/2).floor
			orden = ordenes[j]  ## recorremos por la prioridad

			can_produce = true
			lotes_total = 0
			orden[0].inventory_units.each do |iu|
				variant = iu.variant
				lotes = BigDecimal((iu.quantity.to_f/variant.lote_minimo.to_f).to_s).ceil
				lotes_total += lotes

				if !iu.variant.can_produce?(lotes)
					can_produce = false
				end
			end

			if can_produce
				url = ENV['api_oc_url'] + "recepcionar/"
  			r = HTTParty.post(url + orden[0].number.to_s, body: {}.to_json, headers: { 'Content-type': 'application/json' })
  			
  			if r.code != 200
  				raise "Error en recepcionar oc"
  			end

				orden[0].atencion = 1
				orden[0].save!
				lotes_total = [lotes_total, 3].min
				orden[0].inventory_units.each do |iu|
					variant = iu.variant
					lotes = BigDecimal((iu.quantity.to_f/variant.lote_minimo.to_f).to_s).ceil
					fabricar(variant, [lotes_total, lotes].min)
					lotes_total -= [lotes_total, lotes].min
				end
				break

			end

			j += 1

			if j >= ordenes.count
				break
			end
		end

	end

	def fabricar(variant, lotes=1)
		lotes.times do |i|
			puts "Hacemos solicitud de fabricacion"
			save_request = FabricarRequest.create!(aceptado: false, sku: variant.sku, cantidad: variant.lote_minimo)
		end
		fabricar_api
	end


	def fabricar_api
		FabricarRequest.where(aceptado: false).each do |request|
			request.with_lock do
				puts "Mandamos a fabricas"

				variant = Spree::Variant.find_by(sku: request.sku)
				stock_location = Spree::StockLocation.where(proposito: "Despacho").first
				Scheduler::ProductosHelper.cargar_nuevos

				variant.recipe.each do |ingredient|
					if stock_location.stock_items.find_by(variant: ingredient.variant_ingredient).count_on_hand < ingredient.amount.to_i
						puts "Hay que mover stock antes de fabricar"
						cambiar_items_a_despacho(Spree::Variant.find(ingredient.variant_ingredient.id), ingredient.amount.to_i)
					end
				end

				puts "Terminamos de mover stock"

				url = ENV['api_url'] + "bodega/fabrica/fabricarSinPago"
				base = 'PUT' + variant.sku + variant.lote_minimo.to_s
				key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
				r = HTTParty.put(url,
												 body: {sku: variant.sku.to_s,
																cantidad: variant.lote_minimo.to_s}.to_json,
												 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
				
				if r.code != 200
					"Error en fabricar"
				end
				
				if r.code == 200
					variant.recipe.each do |ingredient|
						stock_movement = stock_location.stock_movements.build(quantity: -ingredient.amount.to_i)
						stock_movement.action = "Mandamos a fabricar."
						stock_movement.stock_item = stock_location.set_up_stock_item(ingredient.variant_ingredient)
						Scheduler::ProductosHelper.cargar_detalles(stock_location.stock_items.find_by(variant: ingredient.variant_ingredient))
					end

					body = JSON.parse(r.body)
					request.aceptado = true
					request.id_prod = body['_id']
					request.grupo = body['grupo']
					request.disponible = body['disponible']
					request.save!
				end
			end
		end
	end

	def cambiar_items_a_despacho(variant, cantidad)  ## siempre vamos a mover para mantener con un stock
		despacho = Spree::StockLocation.where(proposito: "Despacho").first
		stock_item = despacho.stock_items.find_by(variant: variant)

		Scheduler::ProductosHelper.cargar_detalles(stock_item)

    q = cantidad
    while q != 0
			productos_ordenados = ProductosApi.no_vencidos.order(:vencimiento)
			a_mover = productos_ordenados.where(stock_item: stock_item.variant.stock_items.where(backorderable: false)).where.not(stock_item: stock_item).group(:vencimiento)  ## quiero limit pero me tira error, asi que lo haremos a la mala
			
      if a_mover.empty?
      	break
      end

			a_mover_prods = a_mover.each

			prod = a_mover_prods.next

			a_mover_prods_count = a_mover.count[prod.vencimiento]

      variants = Hash.new(0)
      variants[prod.stock_item.variant] = [a_mover_prods_count, q].min

      begin
	      stock_transfer = Spree::StockTransfer.create(reference: "Para poder despachar orden")
	      stock_transfer.transfer(prod.stock_item.stock_location,
	                              despacho,
	                              variants)
	      Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs
	    rescue ActiveRecord::RecordInvalid => e
      		puts e
      		prod.destroy!
      		return cambiar_items_a_despacho(variant, q)
      end

      q -= [a_mover_prods_count, q].min
    end
	end

	def cambiar_almacen
		# primero las que compramos por spree
		Spree::Order.where(channel: "spree", shipment_state: "backorder").where.not(completed_at: nil).each do |orden|  ## estas son las que se compran por ecomerce, hay que si o si atenderlas asap
			orden.with_lock do
				orden.shipments.each do |shipment|
					shipment.with_lock do
						shipment.inventory_units.each do |iu|
							iu.with_lock do
								puts "Cambiamos de almacen una orden por spree"

								# cambiamos los prod al almacen de despacho
								cambiar_items_a_despacho(Spree::Variant.find(iu.variant.id), iu.quantity.to_i)

								# cambiamos el shipment de backorder a almacen de despacho
								Spree::Shipment.find(shipment.id).transfer_to_location(
																										Spree::Variant.find(iu.variant.id),
																										iu.quantity.to_i,
																										Spree::StockLocation.where(proposito: "Despacho").first)
							end
						end
					end
				end
			end
		end

		# ahora vemos las mayoristas
		Spree::Order.where(state: "complete", channel: "ftp", shipment_state: "backorder", atencion: 1).where.not(completed_at: nil).each do |orden|
			orden.with_lock do
				orden.shipments.each do |shipment|
					shipment.with_lock do
						shipment.inventory_units.each do |iu|
							iu.with_lock do
								variant = iu.variant
								if variant.total_on_hand > 0
									puts "Cambiamos de almacen una orden por ftp"

									cantidad = [iu.quantity.to_i, variant.total_on_hand].min

									# cambiamos los prod al almacen de despacho
									cambiar_items_a_despacho(variant, cantidad)

									# cambiamos el shipment de backorder a almacen de despacho
									Spree::Shipment.find(shipment.id).transfer_to_location(
																											variant,
																											cantidad.to_i,
																											Spree::StockLocation.where(proposito: "Despacho").first)
								end
							end
						end
					end
				end
			end
		end

	end

end