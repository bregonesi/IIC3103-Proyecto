module Scheduler::OrderHelper

	def marcar_vencidas
		puts "Viendo si hay que marcar vencidas"

		SftpOrder.vencidas.where.not(myEstado: ["rechazada", "anulada"]).or(
					SftpOrder.vencidas.where.not(serverEstado: ["rechazada", "anulada"])).each do |sftp_order|
			puts "Marcando " + sftp_order.oc.to_s + " como rechazada"

			r = HTTParty.post(ENV['api_oc_url'] + "rechazar/" + sftp_order.oc.to_s,
												body: { rechazo: "Orden se encuentra fuera de plazo" }.to_json,
												headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]
				sftp_order.myEstado = "rechazada"
				sftp_order.serverEstado = body['estado']
				sftp_order.save!
			else
				puts r
			end
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

		if SftpOrder.acepto?  ## ie, si tengo una tasa de aceptadas menor a 0.6
			ordenes = []  # [orden, costo_un_lote, lotes, costo_total]
			#fechaEntrega: 16.hours.ago..Float::INFINITY
			ordenes_creadas = SftpOrder.creadas.each do |sftp_order|
				variant = Spree::Variant.find_by(sku: sftp_order.sku)

				costo = variant.ingredients.sum(:lote_minimo)  ## llamamos costo a la cantidad de productos que hay que utilizar

				cantidad_efectiva = sftp_order.cantidad - variant.total_on_hand

				if !variant.primary?
					costo_lote = variant.lote_minimo
					lotes = BigDecimal((cantidad_efectiva.to_f / variant.lote_minimo.to_f).to_s).ceil
				else
					costo_lote = 1
					lotes = cantidad_efectiva
				end
				lotes = [lotes, 0].max  ## por si tengo mas de lo que me pide

				ordenes << [sftp_order, costo_lote, lotes, costo_lote * lotes]
			end

			ordenes = ordenes.sort_by{ |i| i[1] }  ## primero ordeno por costo de un lote
			ordenes = ordenes.sort_by{ |i| i[3] }  ## despues ordeno por costo total
			# asi va a quedar mas importante costo total y luego el costo de un lote

			ordenes.each do |orden_entry|
				if !SftpOrder.acepto?  ## si ya cumpli mi cuota
					break
				end

				orden = orden_entry[0]
				variant = Spree::Variant.find_by(sku: orden.sku)

				if ( (variant.can_produce? && orden.fechaEntrega - DateTime.now() >= 6.hours.seconds) || variant.can_ship? ) || (variant.primary? && variant.can_ship?)  ## sino no alcanzamos a fabricar
					puts "acepto oc " + orden.oc.to_s
					if !variant.primary?  ## hay que fabricar
						puts "hay q fabricar"
						orden.myEstado = "preaceptada"
						lotes_restante_fabricar = orden_entry[2]
						while variant.can_produce? && lotes_restante_fabricar > 0  ## si hay que fabricar y si tengo que fabricar
							puts "fabrico"
							lotes_restante_fabricar -= 1
						end
					else  ## acepto de inmediato
						puts "es materia prima"
						if variant.can_ship?
							puts "tengo para despachar"
							create_spree_from_sftp_order(orden)
						end
					end
				end

			end

		end
	end

	def create_spree_from_sftp_order(sftp_order)
		puts "Creando spree order from sftp order"

		if sftp_order.myEstado != "aceptada"
			r = HTTParty.post(ENV['api_oc_url'] + "recepcionar/" + sftp_order.oc.to_s,
													body: { }.to_json,
													headers: { 'Content-type': 'application/json' })
			puts r
		end

		if sftp_order.myEstado == "aceptada" || r.code == 200
			if sftp_order.myEstado != "aceptada"
				sftp_order.myEstado = "aceptada"
				sftp_order.serverEstado = "aceptada"
				sftp_order.save!
			end

			variant = Spree::Variant.find_by!(sku: sftp_order.sku)
			cantidad_restante = sftp_order.cantidad - sftp_order.myCantidadDespachada
			cantidad_despachar = [cantidad_restante, variant.total_on_hand].min
			cantidad_despachar = 10  ## ELIMINAR ESTO DESPUES
			recien_creada = false

			spree_order = Spree::Order.where(number: sftp_order.oc,
																			 email: 'spree@example.com').first_or_create! do |o|
				puts "Creando spree order " + sftp_order.oc
				recien_creada = true

				o.contents.add(variant, cantidad_despachar.to_i, {})  ## variant, quantity, options
				o.update_line_item_prices!
				o.create_tax_charge!
				o.next!  # pasamos a address

				o.bill_address = Spree::Address.first
				o.ship_address = Spree::Address.first
				o.next!  # pasamos a delivery

				o.create_proposed_shipments
				o.next!  # pasamos a payment

				payment = o.payments.where(amount: BigDecimal(o.total, 4),
																	 payment_method: Spree::PaymentMethod.where(name: 'Gratis', active: true).first).first_or_create!
				payment.update_columns(state: 'checkout')

				o.confirmation_delivered = true  ## forzamos para que no se envie mail
				o.next!  # pasamos a complete

				o.channel = "ftp"
			end

			if !recien_creada && spree_order
				puts "hay q agregar nuevo stock"
			end
=begin
      if orden_nueva.channel != "ftp"  # si es primera vez que la creamos
				r = HTTParty.get(url + content_id, headers: { 'Content-type': 'application/json' })
				if r.code != 200
					raise "Error en get oc."
				end
				body = JSON.parse(r.body)[0]

        orden_nueva.completed_at = DateTime.strptime((date_ingreso.to_f / 1000).to_s, '%s')
        orden_nueva.channel = "ftp"
				orden_nueva.fechaEntrega = body['fechaEntrega']

        if body['estado'] == "aceptada"
          orden_nueva.atencion = 1
        elsif body['estado'] == "finalizada"
          orden_nueva.atencion = 2
        end

        orden_nueva.save!

        if Time.now() >= orden_nueva.fechaEntrega || body['estado'] == "rechazada" || body['estado'] == "anulada"   ## chequeat q no haya sido ni despachado algo o terminada
          r = HTTParty.post(ENV['api_oc_url'] + "rechazar/" + orden_nueva.number.to_s, body: {}.to_json, headers: { 'Content-type': 'application/json' })
          orden_nueva.canceled_by(Spree::User.first)
        end
      end
=end
		end
	end

	def chequear_si_hay_stock
		##
		## Si hay stock creo otra 'create_spree_from_sftp_order'
		## Y si tengo que producir creo otra orden para fabricar
		##
		puts "Chequeando si hay stock"

		(SftpOrder.aceptadas + SftpOrder.preaceptadas).each do |sftp_order|
			variant = Spree::Variant.find_by(sku: sftp_order.sku)
			cantidad_restante = sftp_order.cantidad - sftp_order.myCantidadDespachada

			if cantidad_restante > 0 && variant.total_on_hand > 0
				puts "Llego stock para una orden aun no finalizada"

				create_spree_from_sftp_order(sftp_order)
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
				puts r
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
			a_mover = productos_ordenados.where(stock_item: stock_item.variant.stock_items.where(backorderable: false)).where.not(stock_item: stock_item)
			a_mover_groupped = a_mover.group(:vencimiento).count(:id)  # todo hay groups y where denuevo ya que postgres tira error
			
      if a_mover.empty?
      	break
      end

			a_mover_datos = a_mover_groupped.each.next

			a_mover_fecha = a_mover_datos[0]
			a_mover_prods_count = a_mover_datos[1]

			prods = productos_ordenados.where(stock_item: stock_item.variant.stock_items.where(backorderable: false)).where.not(stock_item: stock_item).where(vencimiento: a_mover_fecha)
			prod = prods.first			

      variants = Hash.new(0)
      variants[prod.stock_item.variant] = [a_mover_prods_count, q].min
	puts variants
      begin
	      stock_transfer = Spree::StockTransfer.create(reference: "Para poder despachar orden")
	      stock_transfer.transfer(prod.stock_item.stock_location,
	                              despacho,
	                              variants)
	      Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs
	    rescue ActiveRecord::RecordInvalid => e
      		puts e
      		prods.destroy_all
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
								variant = Spree::Variant.find(iu.variant.id)
								if variant.total_on_hand > 0
									puts "Cambiamos de almacen una orden por ftp"

									cantidad = [iu.quantity.to_i, variant.total_on_hand].min
									puts "cantidad" + cantidad.to_s
									# cambiamos los prod al almacen de despacho
									cambiar_items_a_despacho(variant, cantidad)
									puts "cambiamos sku a despacho"+variant.sku.to_s
									# cambiamos el shipment de backorder a almacen de despacho
									Spree::Shipment.find(shipment.id).transfer_to_location(
																											variant,
																											cantidad.to_i,
																											Spree::StockLocation.where(proposito: "Despacho").first)
									puts "hacemos shipment sku "+variant.sku
								end
							end
						end
					end
				end
			end
		end

	end

end
