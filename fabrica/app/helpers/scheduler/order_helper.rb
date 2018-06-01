module Scheduler::OrderHelper

	def marcar_vencidas
		puts "Viendo si hay que marcar vencidas"

		SftpOrder.vencidas.where(serverEstado: "creada").each do |sftp_order|
			puts "Marcando " + sftp_order.oc.to_s + " como rechazada"
			sftp_order.rechazo = "Orden se encuentra fuera de plazo"

			r = HTTParty.post(ENV['api_oc_url'] + "rechazar/" + sftp_order.oc.to_s,
												body: { rechazo: sftp_order.rechazo }.to_json,
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

	def marcar_finalizadas
		puts "Viendo si hay que marcar finalizadas"

		SftpOrder.where(myEstado: "finalizada").where.not(serverEstado: "finalizada").each do |sftp_order|
			puts "Viendo si hay que marcar " + sftp_order.oc.to_s + " como finalizada"

			r = HTTParty.get(ENV['api_oc_url'] + "obtener/" + sftp_order.oc.to_s,
											 body: { }.to_json,
											 headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]
				serverEstado = body['estado']

				sftp_order.serverCantidadDespachada = body['cantidadDespachada']
				if serverEstado == "finalizada"
					sftp_order.serverEstado = serverEstado
				else
					puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
					puts "!! ATENCION: OC " + sftp_order.oc.to_s + " NO ESTA COMO FINALIZADA EN EL SERVIDOR PERO SI EN NUESTRA APP !!"
					puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				end
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
					puts "Acepto oc " + orden.oc.to_s
					if !variant.primary?  ## hay que fabricar
						puts "Hay q fabricar"
						lotes_restante_fabricar = orden_entry[2]
						while variant.can_produce? && lotes_restante_fabricar > 0  ## si hay que fabricar y si tengo que fabricar
							puts "Fabrico"
							orden.myEstado = "preaceptada"
							orden.save!
							fabricar(orden)
							lotes_restante_fabricar -= 1
						end
					else  ## acepto de inmediato
						puts "Es materia prima"
						if variant.can_ship?
							puts "Tengo para despachar"
							create_spree_from_sftp_order(orden)
						end
					end
				end

			end

		end
	end

	def create_spree_from_sftp_order(sftp_order)
		puts "Creando spree order from sftp order"

		sftp_order.with_lock do

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
				#cantidad_despachar = 10  ## solo para testeo
				recien_creada = false

				spree_order = sftp_order.order
				if spree_order.nil?
					sftp_order.build_order(number: sftp_order.oc,
																 email: 'spree@example.com') do |o|
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
					sftp_order.save!
				end

				if !recien_creada && spree_order
					puts "Agregando stock a orden ya creada. Number: " + spree_order.number

					spree_order.with_lock do

						shipment_quantity_left = cantidad_despachar
						new_shipments = []
						while shipment_quantity_left > 0
							Spree::StockLocation.almacenes.each do |almacen|
								stock_item = almacen.stock_items.find_by(variant: variant, count_on_hand: 1..Float::INFINITY)
								if !stock_item.nil?
									cantidad_despachar_shipment = [stock_item.count_on_hand, shipment_quantity_left].min
									new_shipments << [almacen, cantidad_despachar_shipment]
									shipment_quantity_left -= cantidad_despachar_shipment
								end

								if shipment_quantity_left == 0
									break
								end
							end

							if shipment_quantity_left > 0
								raise "Error en generar nuevo shipment para orden ya creada. Faltan " + shipment_quantity_left.to_s + " unidades"
							end
						end

						new_shipments.each do |new_shipment|
							shipment = spree_order.shipments.find_by(stock_location: new_shipment[0])
							if shipment.nil?
								shipment = spree_order.shipments.create(stock_location: new_shipment[0])
							end

							spree_order.contents.add(variant, new_shipment[1].to_i, shipment: shipment)  ## variant, quantity, options
						end

						if !new_shipments.empty?
							# nuevo payment ya que se agrego producto
							payment = spree_order.payments.build(amount: BigDecimal(spree_order.outstanding_balance, 4),
																									 payment_method: Spree::PaymentMethod.where(name: 'Gratis', active: true).first)
							payment.save!
						end
						
						sftp_order.myCantidadDespachada += cantidad_despachar.to_i
						sftp_order.save!
					end
				end
			end
		end
	end

	def chequear_si_hay_stock
		##
		## Si hay stock creo otra 'create_spree_from_sftp_order'
		## Y si tengo que producir creo otra orden para fabricar
		##
		puts "Chequeando si hay stock"

		SftpOrder.where(id: (SftpOrder.aceptadas + SftpOrder.preaceptadas)).vigentes.each do |sftp_order|
			variant = Spree::Variant.find_by(sku: sftp_order.sku)
			cantidad_restante = sftp_order.cantidad - sftp_order.myCantidadDespachada

			if cantidad_restante > 0
				if variant.total_on_hand > 0  ## si tengo stock creo shipments
					puts "Llego stock para una orden aun no finalizada"

					create_spree_from_sftp_order(sftp_order)
				end

				cantidad_en_fabricacion = sftp_order.fabricar_requests.where(aceptado: false).or(sftp_order.fabricar_requests.where(aceptado: true, disponible: Time.at(0)..DateTime.now())).map(&:cantidad).reduce(:+).to_i
				if cantidad_restante - cantidad_en_fabricacion > 0
					puts "Falta para fabricar"
					if variant.can_produce?
						puts "Voy a producir"
						fabricar(sftp_order)
					end
				end
			end
		end
	end

	def fabricar(sftp_order, lotes=1)
		variant = Spree::Variant.find_by(sku: sftp_order.sku)
		lotes.times do |i|
			puts "Hacemos solicitud de fabricacion"
			sftp_order.fabricar_requests.build(aceptado: false, sku: variant.sku, cantidad: variant.lote_minimo)
			sftp_order.save!
		end
		#fabricar_api
	end


	def fabricar_api
		FabricarRequest.where(aceptado: false).each do |request|
			request.with_lock do
				puts "Mandamos a fabricar"

				variant = Spree::Variant.find_by(sku: request.sku)
				Scheduler::ProductosHelper.cargar_nuevos

				if !variant.can_produce?  ## por si me robaron el stock
					puts "Se destruye orden de fabricacion ya que no se cuenta con los productos disponibles"
					request.destroy
					return fabricar_api
				end

				variant.recipe.each do |ingredient|
					disponible_en_despacho = variant.stock_items.where(stock_location: Spree::StockLocation.where(proposito: "Despacho")).map(&:count_on_hand).reduce(:+)
					if disponible_en_despacho.to_i < ingredient.amount.to_i
						puts "Hay que mover stock antes de fabricar"
						cambiar_items_a_despacho(ingredient.variant_ingredient, ingredient.amount.to_i - disponible_en_despacho.to_i)
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
						stock_location = ingredient.variant_ingredient.stock_items.where(stock_location: Spree::StockLocation.generales).order(count_on_hand: :desc).first.stock_location
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
		puts "Ejecutando cambiar items a despacho"

		despachos = Spree::StockLocation.despachos.order(capacidad_maxima: :desc)
    despacho_escogido = nil
    despachos.each do |despacho_entry|
    	if despacho_entry.available_capacity >= cantidad
    		despacho_escogido = despacho_entry
    		break
    	end
    end
    if despacho_escogido.nil?
    	raise "Error en escoger despacho para cambiar item a despacho"
    end

		#stock_item = despacho_escogido.stock_items.find_by(variant: variant)
		candidatos = variant.stock_items.where(id: (Spree::StockLocation.almacenes - despachos).map(&:stock_items).flatten)

		candidatos.each do |c|
			cargar_detalles(c)  ## por si aparecen nuevos stocks q agregar
		end

    q = cantidad
    while q > 0
			productos_ordenados = ProductosApi.no_vencidos.order(:vencimiento)
			a_mover = productos_ordenados.where(stock_item: candidatos)
			a_mover_groupped = a_mover.group(:stock_item_id, :vencimiento).count(:id)  # todo hay groups y where denuevo ya que postgres tira error
			
      if a_mover.empty?
      	break
      end

			puts "Cambiando a " + despacho_escogido.proposito + " (" + despacho_escogido.name + ") q " + q.to_s + " y queremos sku " + variant.sku

			a_mover_datos = a_mover_groupped.each.next

			a_mover_stock_item = a_mover_datos[0][0]
			a_mover_fecha = a_mover_datos[0][1]
			a_mover_prods_count = a_mover_datos[1]

			prods = productos_ordenados.where(stock_item: a_mover_stock_item, vencimiento: a_mover_fecha)
			prod = prods.first	

      variants = Hash.new(0)
      variants[prod.stock_item.variant] = [a_mover_prods_count, q].min

			begin
				puts "Moveremos " + variants.to_s + " desde almacen " + prod.stock_item.stock_location.name + " a " + despacho_escogido.name

        stock_transfer = Spree::StockTransfer.create(reference: "Para tener capacidades 'optimas'")
        stock_transfer.transfer(prod.stock_item.stock_location,
                                despacho_escogido,
                                variants)
      rescue ActiveRecord::RecordInvalid => e  ## por si tira error (no esta sincronizado)
    		puts e
    		stock_transfer.destroy
				prods.destroy_all
    		#prod.stock_item.stock_location.stock_items.each do |x|
    		#	Scheduler::ProductosHelper::cargar_detalles(x)
    		#end
    		return cambiar_items_a_despacho(variant, cantidad)
    		break
    	end

    	Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs

      q -= [a_mover_prods_count, q].min
    end
    #return true
	end

	def cambiar_almacen
		puts "Cambiando de almacen las ordenes listas"

		Spree::Order.where(state: "complete", shipment_state: "ready", payment_state: "paid").each do |orden|
			orden.with_lock do
				orden.shipments.each do |shipment|
					shipment.with_lock do
						if shipment.stock_location.proposito != "Despacho"
							a_mover = {}
							shipment.line_items.each do |li|
								li.with_lock do
									variant_li = li.variant

									cantidad_en_despachos = variant_li.stock_items.where(stock_location: Spree::StockLocation.despachos).map(&:count_on_hand).reduce(:+).to_i
									cantidad_mover_a_despacho = [li.quantity - cantidad_en_despachos, 0].max

									puts "Moviendo " + variant_li.sku + " unidades: " + cantidad_mover_a_despacho.to_s
									# Sacamos del shipment original
									orden.contents.remove(variant_li, li.quantity, shipment: shipment)

									if a_mover[variant_li].nil?
										a_mover[variant_li] = []
									end
									a_mover[variant_li] << li.quantity
									puts a_mover

									# Movemos al almacen de despacho
									if cantidad_mover_a_despacho > 0
										cambiar_items_a_despacho(variant_li, cantidad_mover_a_despacho)
									end
								end
							end

							shipment.destroy!  ## destruimos el otro
							shipment_despacho = orden.shipments.find_by(stock_location: Spree::StockLocation.despachos)
							if shipment_despacho.nil?
								puts "Reutilizando shipment"
								## si no hay shipment de despacho lo creamos
								shipment_despacho = orden.shipments.create(stock_location: Spree::StockLocation.despachos.order(capacidad_maxima: :desc).first)
							else
								puts "Shipment ya existia"
							end

							a_mover.each do |key, array|
								# Agregamos al shipment de despacho
								orden.contents.add(key, array.sum.to_i, shipment: shipment_despacho)  ## variant, quantity, options
							end

						end
					end
				end
			end
		end
	end

end
