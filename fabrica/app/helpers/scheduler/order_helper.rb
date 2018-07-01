module Scheduler::OrderHelper
#linea 149 y cercnas
#linea 298 y cercanas

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
				sftp_order.serverCantidadDespachada = body['cantidadDespachada']
				sftp_order.server_updated_at = body['updated_at']
				sftp_order.save!
			else
				puts r
			end
		end
	end

	def sincronizar_informacion
		puts "Viendo si hay que sincronizar ocs"

		SftpOrder.where('"sftp_orders"."myCantidadDespachada" != "sftp_orders"."serverCantidadDespachada"').each do |sftp_order|
			puts "Viendo si hay que actualizar las unidades despachadas de " + sftp_order.oc.to_s

			r = HTTParty.get(ENV['api_oc_url'] + "obtener/" + sftp_order.oc.to_s,
											 body: { }.to_json,
											 headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]

				sftp_order.serverEstado = body['estado']
				sftp_order.serverCantidadDespachada = body['cantidadDespachada']

				cantidad_no_despachada = 0
				cantidades = sftp_order.orders.where.not(shipment_state: "shipped").map(&:quantity)
				if !cantidades.empty?
					cantidad_no_despachada = cantidades.reduce(:+).to_i  ## en realidad esta por despachar
				end

				if sftp_order.myCantidadDespachada - cantidad_no_despachada != sftp_order.serverCantidadDespachada
					puts "Hay un error en cantidades despachadas"

					if sftp_order.server_updated_at != body['updated_at']  # solo si han habido cambios y no calza actualizo
						sftp_order.myCantidadDespachada = sftp_order.serverCantidadDespachada + cantidad_no_despachada
					end
					
					#sftp_order.myEstado = "creada"
					sftp_order.myEstado = sftp_order.serverEstado  ## la linea de arriba funciona, pero esta es mejor
				end

				if sftp_order.myCantidadDespachada >= sftp_order.cantidad
					sftp_order.myEstado = "finalizada"
				end

				sftp_order.server_updated_at = body['updated_at']
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

				if body.nil?
					puts "ERROR: Obtener oc retorno vacio"
					next
				end

				serverEstado = body['estado']

				sftp_order.serverCantidadDespachada = body['cantidadDespachada']
				sftp_order.server_updated_at = body['updated_at']
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

		if SftpOrder.acepto?  ## ie, si tengo una tasa de aceptadas menor a 0.75
			ordenes = []  # [orden, costo_un_lote, lotes, costo_total]
			#fechaEntrega: 16.hours.ago..Float::INFINITY
			ordenes_creadas = SftpOrder.creadas.each do |sftp_order|
				variant = Spree::Variant.find_by(sku: sftp_order.sku)

				ingreso = sftp_order.cantidad * sftp_order.precioUnitario

				cantidad_efectiva = sftp_order.cantidad - variant.cantidad_disponible
				cantidad_fab = 0

				if !variant.primary?
					costo_lote = variant.lote_minimo * variant.cost_price.to_i
					costo = costo_lote.to_f

					variant.recipe.each do |ingredient|
						costo += ingredient.variant_ingredient.cost_price.to_i * ingredient.amount
						cantidad_fab = ingredient.amount - ingredient.variant_ingredient.cantidad_disponible  # eliminar esto, es para ordenar por el q ocupa menos cantidad para fabricar
					end

					lotes_solicitados = sftp_order.cantidad.to_f / variant.lote_minimo.to_f
					costo = costo * lotes_solicitados

					lotes = BigDecimal((cantidad_efectiva.to_f / variant.lote_minimo.to_f).to_s).ceil
				else
					costo = variant.cost_price.to_i * cantidad_efectiva
					lotes = cantidad_efectiva
				end

				ganancia = ingreso.to_f - costo.to_f
				ganancia_por_producto = ganancia.to_f / sftp_order.cantidad.to_f

				lotes = [lotes, 0].max  ## por si tengo mas de lo que me pide

				if SftpOrder.acepto? || ganancia_por_producto >= 0
					#ordenes << [sftp_order, sftp_order.cantidad, lotes, ganancia_por_producto]
					ordenes << [sftp_order, sftp_order.cantidad, lotes, cantidad_efectiva + cantidad_fab]  # dejo cantidad efectiva ya que aun no cobro
				end
			end

			ordenes = ordenes.sort_by{ |i| i[1] }  ## primero ordeno por cantidad de productos
			ordenes = ordenes.sort_by{ |i| i[3] }  ## despues ordeno por ganancia por producto
			# hay que descomentar el reverse cuando se cambie a ganancia
			#ordenes.reverse!  ## doy vuelta para que queden con mas ganancia al principio
			# asi va a quedar mas importante la ganancia por producto y luego la cantidad de productos a despachar
			#puts ordenes.to_yaml

			ordenes.each do |orden_entry|
				if !SftpOrder.acepto?  ## si ya cumpli mi cuota
					break
				end

				orden = orden_entry[0]
				variant = Spree::Variant.find_by(sku: orden.sku)

				if (1)  ## sino no alcanzamos a fabricar
					puts "Veo si acepto oc " + orden.oc.to_s
					if !variant.primary?
						puts "No es materia prima"
						if variant.can_ship?
							puts "Tengo para despachar"
							create_spree_from_sftp_order(orden)
						else
							lotes_restante_fabricar = orden_entry[2]
							while lotes_restante_fabricar > 0  ## si hay que fabricar y si tengo que fabricar
								cantidad_en_fabricacion = orden.fabricar_requests.por_fabricar.or(orden.fabricar_requests.por_recibir).map(&:cantidad).reduce(:+).to_i
								cantidad_en_ocs = orden.oc_requests.por_recibir.where(sku: orden.sku).map(&:cantidad).reduce(:+).to_i
								cantidad_faltante = orden.cantidad - cantidad_en_fabricacion - cantidad_en_ocs
								offset = cantidad_faltante % variant.lote_minimo  ## offset es lo que falta en el ultimo lote
								relacion_lote_faltante = offset.to_f / variant.lote_minimo.to_f
								# Si fabrico y el lote que me resulta es menos de 1/3 del ultimo lote, entonces compro por oc
								# Sino fabrico
								# Si no puedo fabricar compro por oc
								if offset > 0 && relacion_lote_faltante > 0 && relacion_lote_faltante <= 1.0/3.0 && orden.puedo_pedir_por_oc(offset)
									puts "Mandamos a generar oc a grupos"
									generar_oc(orden, offset)
									orden.myEstado = "preaceptada"
								elsif variant.can_produce?
									if orden.fechaEntrega - DateTime.now.utc >= 6.hours.seconds
										puts "Voy a fabricar"
										fabricar(orden)
										orden.myEstado = "preaceptada"
									else
										if orden.puedo_pedir_por_oc(variant.lote_minimo)
											puts "Pedire un lote entero ya que no alcanzo a fabricar."
											generar_oc(orden, variant.lote_minimo)
											orden.myEstado = "preaceptada"
										end
									end
								else
									puts "No puedo fabricar."
									if orden.puedo_pedir_por_oc(variant.lote_minimo)
										puts "Pedire un lote entero."
										generar_oc(orden, variant.lote_minimo)
										orden.myEstado = "preaceptada"
									else
										puts "Voy a pedir las materias primas para fabricar"
										variant.materias_faltantes_producir.each do |sku, cantidad|
											if orden.puedo_pedir_por_oc(cantidad.to_i, sku)
												puts "Pediremos " + sku.to_s + " en cantidad de " + cantidad.to_s
												generar_oc(orden, cantidad.to_i, sku)
												orden.myEstado = "preaceptada"
											end
										end
									end
								end
								#fabricar(orden)
								lotes_restante_fabricar -= 1
							end
							orden.save!
						end
					else
						puts "Es materia prima"
    				promedios = Recipe.promedios
						if orden_entry[1] <= (variant.cantidad_disponible - promedios[variant.sku.to_s].to_i * 3) && variant.can_ship?
							puts "Tengo para despachar"
							create_spree_from_sftp_order(orden)
						else
							pedir = [variant.lote_minimo, orden.cantidad].min
							puts "Genero oc por " + pedir.to_s + " unidades"
							if orden.puedo_pedir_por_oc(pedir)
								generar_oc(orden, pedir)
								orden.myEstado = "preaceptada"
								orden.save!
							end
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

					r2 = HTTParty.get(ENV['api_oc_url'] + "obtener/" + sftp_order.oc.to_s,
														body: { }.to_json,
														headers: { 'Content-type': 'application/json' })

					if r2.code == 200
						body = JSON.parse(r2.body)[0]
						sftp_order.server_updated_at = body['updated_at']
					end
					
					sftp_order.save!

					# Creo la factura para FTP #
					if sftp_order.canal == "ftp"
						factura = Invoice.where(originator_type: sftp_order.class.name.to_s, originator: sftp_order.id.to_i).first_or_create! do |f|
							
							factura_request = HTTParty.put(ENV['api_sii_url'],
																						 body: {oc: sftp_order.oc}.to_json,
																						 headers: { 'Content-type': 'application/json'})
			
							puts factura_request

							if factura_request.code == 200
								body = JSON.parse(factura_request.body)
								f._id = body["_id"]
								f.cliente = body["cliente"]
								f.proveedor = body["proveedor"]
								f.oc = body["oc"]["_id"]
								f.bruto = body["bruto"]
								f.iva = body["iva"]
								f.total = body["total"]
								f.estado = body["estado"]
								f.created_at = body["created_at"]
								f.updated_at = body["updated_at"]
							else
								puts "Error en crear factura"
								puts factura_request
							end
						end
					end

				end

				variant = Spree::Variant.find_by!(sku: sftp_order.sku)
				cantidad_restante = sftp_order.cantidad - sftp_order.myCantidadDespachada
				cantidad_disponible = variant.cantidad_disponible
				if variant.primary?
    			promedios = Recipe.promedios
					cantidad_disponible = cantidad_disponible - promedios[variant.sku.to_s].to_i * 3
					cantidad_disponible = [cantidad_disponible, 0].max
				end
				cantidad_despachar = [cantidad_restante, cantidad_disponible].min
				puts "create sftp order con cantidad despachar " + cantidad_despachar.to_s
				recien_creada = false

				spree_orders = sftp_order.orders.where.not(shipment_state: "shipped").joins(:shipments).where.not('"spree_shipments"."stock_location_id" = ?', Spree::StockLocation.despachos.map(&:id))
				spree_order = spree_orders.empty? ? nil : spree_orders.first
				if spree_order.nil?
					n_orden = sftp_order.orders.count + 1
					new_order = sftp_order.orders.build(number: sftp_order.oc + " - " + n_orden.to_s,
																							email: 'spree@example.com') do |o|
						puts "Creando spree order " + sftp_order.oc + " - " + n_orden.to_s
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

						o.channel = sftp_order.canal
					end
					new_order.save!
					sftp_order.myCantidadDespachada += cantidad_despachar.to_i
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
									puts "creando shipment con cantidad despachar " + cantidad_despachar_shipment.to_s
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
							shipment = spree_order.shipments.where.not(state: "shipped").find_by(stock_location: new_shipment[0])
							if shipment.nil?
								shipment = spree_order.shipments.create(stock_location: new_shipment[0], address: spree_order.ship_address)
							end

							spree_order.contents.add(variant, new_shipment[1].to_i, shipment: shipment)  ## variant, quantity, options
							puts "Agregando a shipment number " + shipment.number + " con cantidad de prods " + new_shipment[1].to_s + " y stock location " + new_shipment[0].name
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
				cantidad_disponible = variant.cantidad_disponible
				if variant.primary?
    			promedios = Recipe.promedios
					cantidad_disponible = cantidad_disponible - promedios[variant.sku.to_s].to_i * 3
					cantidad_disponible = [cantidad_disponible, 0].max
				end

				if cantidad_disponible > 0  ## si tengo stock creo shipments
					puts "Llego stock para una orden aun no finalizada"

					create_spree_from_sftp_order(sftp_order)
				end

				cantidad_en_fabricacion = (sftp_order.fabricar_requests.por_fabricar + sftp_order.fabricar_requests.por_recibir).map(&:cantidad).reduce(:+).to_i
				cantidad_en_ocs = sftp_order.oc_requests.por_recibir.where(sku: sftp_order.sku).map(&:cantidad).reduce(:+).to_i
				cantidad_faltante = cantidad_restante - cantidad_en_fabricacion - cantidad_en_ocs
				offset = cantidad_faltante % variant.lote_minimo  ## offset es lo que falta en el ultimo lote
				relacion_lote_faltante = variant.primary? ? 0.01 : offset.to_f / variant.lote_minimo.to_f
				if cantidad_faltante > 0
					puts "Faltan " + cantidad_faltante.to_s + " productos."
					puts "Lotes minimo de producto faltante " + variant.lote_minimo.to_s
					puts "Relacion faltante lote " + relacion_lote_faltante.to_s
					# Si fabrico y el lote que me resulta es menos de 1/3 del ultimo lote, entonces compro por oc
					# Sino fabrico
					# Si no puedo fabricar compro por oc
					if offset > 0 && relacion_lote_faltante > 0 && relacion_lote_faltante <= 1.0/3.0 && sftp_order.puedo_pedir_por_oc(offset)
						puts "Mandamos a generar oc a grupos"
						generar_oc(sftp_order, offset)
					elsif variant.can_produce? && sftp_order.fechaEntrega - DateTime.now.utc >= 6.hours.seconds
						puts "Voy a fabricar"
						fabricar(sftp_order)
					else
						puts "No puedo fabricar."
						pedir = [variant.lote_minimo, cantidad_faltante].min
						if sftp_order.puedo_pedir_por_oc(pedir)
							puts "Pedire lo que falta o un lote minimo (" + pedir.to_s + " unidades)."
							generar_oc(sftp_order, pedir)
						else
							if sftp_order.fechaEntrega - DateTime.now.utc >= 6.hours.seconds
								puts "Voy a pedir materias primas para fabricar"
								variant.materias_faltantes_producir.each do |sku, cantidad|
									if sftp_order.puedo_pedir_por_oc(cantidad.to_i, sku)
										puts "Pediremos " + sku.to_s + " en cantidad de " + cantidad.to_s
										generar_oc(sftp_order, cantidad.to_i, sku)
									end
								end
							else
								puts "Tampoco pido materias primas por que vence pronto"
							end
						end
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
		pago_activado = true
		FabricarRequest.por_fabricar.each do |request|
			request.with_lock do
				variant = Spree::Variant.find_by(sku: request.sku)

				puts "Mandamos a fabricar " + variant.sku

				if variant.primary?  ## por si llega una materia prima aca
					puts "Se destruye orden de fabricacion ya que no se pueden fabricar materias primas"
					request.destroy
					next
				end

				if !request.can_produce?  ## por si me robaron el stock
					puts "Se destruye orden de fabricacion ya que no se cuenta con los productos disponibles"
					request.destroy
					next
				end

				if request.sftp_order.fechaEntrega < 6.hours.from_now.utc  ## no voy a fabricar algo que vence dentro de 6 hrs
					puts "Rechazando por que vence pronto"
					request.razon = "Quedan menos de 6 horas para que caduque. No voy a fabricar"
					request.save!
					next
				end
				
				#Scheduler::ProductosHelper.cargar_nuevos

				a_cambiar = []
				variant.recipe.each do |ingredient|
					disponible_en_despacho = ingredient.variant_ingredient.stock_items.where(stock_location: Spree::StockLocation.despachos).map(&:count_on_hand).reduce(:+).to_i
					puts "Disponible de sku " + ingredient.variant_ingredient.sku + " en despacho: " + disponible_en_despacho.to_s
					#ingredient.variant_ingredient.stock_items.each { |si| Scheduler::ProductosHelper.cargar_detalles(si) }
					if ingredient.amount.to_i > disponible_en_despacho.to_i
						puts "Hay que mover stock antes de fabricar"
						a_cambiar << [ingredient.variant_ingredient, ingredient.amount.to_i - disponible_en_despacho.to_i]
						#cambiar_items_a_despacho(ingredient.variant_ingredient, ingredient.amount.to_i - disponible_en_despacho.to_i)
					end
				end

				capacidad_requerida = a_cambiar.map{|e| e[1]}.sum
				almacen_despacho = Spree::StockLocation.despachos.order(capacidad_maxima: :desc).first
				if capacidad_requerida + 100 > almacen_despacho.available_capacity  # dejaremos un gap de 100
					puts "Se requiere cambiar a despacho mas del espacio que hay. Saltamos fabricacion"
					puts a_cambiar.inspect
					next
				end
				#next
				a_cambiar.each do |e|
					puts "Cambiando a despacho " + e.inspect
					cambiar_items_a_despacho(e[0], e[1], "Para poder fabricar")
				end

				puts "Terminamos de mover stock"

				#next

				if pago_activado
					# Transferencia antes de fabricar
					transferencia = Transferencium.where(originator_type: request.class.name.to_s, originator_id: request.id.to_i).first_or_create! do |t|
						t.origen = $info_grupos[4][:id_banco]
						t.destino = Spree::Store.first.cuenta_banco
						t.monto = request.cantidad.to_i * variant.cost_price.to_i

						transferencia_request = HTTParty.put(ENV['api_banco_url'] + "trx",
																								 body: {origen: t.origen,
																								 				destino: t.destino,
																								 				monto: t.monto}.to_json,
																								 headers: { 'Content-type': 'application/json'})
		
						puts transferencia_request

						if transferencia_request.code == 200
							body = JSON.parse(transferencia_request.body)
							t.idtransferencia = body["_id"]
						else
							puts "Error en transferencia"
							puts transferencia_request
						end
					end

					# Ahora mandamos a fabricar
					base = 'PUT' + variant.sku + request.cantidad.to_s + transferencia.idtransferencia.to_s
					key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
					r = HTTParty.put(ENV['api_url'] + "bodega/fabrica/fabricar",
													 body: {trxId: transferencia.idtransferencia.to_s,
													 				sku: variant.sku.to_s,
																	cantidad: request.cantidad.to_s}.to_json,
													 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
				else
					base = 'PUT' + variant.sku + request.cantidad.to_s
					key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
					r = HTTParty.put(ENV['api_url'] + "bodega/fabrica/fabricarSinPago",
													 body: {sku: variant.sku.to_s,
																	cantidad: request.cantidad.to_s}.to_json,
													 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
				end

				puts r
				if r.code != 200
					"Error en fabricar"
				end
				
				if r.code == 200
					variant.recipe.each do |ingredient|
						stock_movement = almacen_despacho.stock_movements.build(quantity: -ingredient.amount.to_i)
						stock_movement.action = "Mandamos a fabricar."
						stock_movement.stock_item = almacen_despacho.set_up_stock_item(ingredient.variant_ingredient)
						stock_movement.save!

						stock_item_ingrediente = almacen_despacho.stock_items.find_by(variant: ingredient.variant_ingredient)
						Scheduler::ProductosHelper.obtener_lote_antiguo(stock_item_ingrediente, cantidad=ingredient.amount.to_i).destroy_all
						Scheduler::ProductosHelper.cargar_detalles(stock_item_ingrediente)
					end

					body = JSON.parse(r.body)
					request.aceptado = true
					request.id_prod = body['_id']
					request.grupo = body['grupo']
					request.disponible = body['disponible']
					request.save!
				end
			end
			#break
		end
	end

	def cambiar_items_a_despacho(variant, cantidad, reference="No se espeficia (ejecutado por cambiar items a despacho")  ## siempre vamos a mover para mantener con un stock
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

    if cantidad > despacho_escogido.available_capacity
    	raise "Se esta intentando mover a despacho mas de la capacidad que se tiene"
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
			a_mover_prods_count = [a_mover_prods_count, Spree::StockItem.find(a_mover_stock_item).count_on_hand].min

			prods = productos_ordenados.where(stock_item: a_mover_stock_item, vencimiento: a_mover_fecha)
			prod = prods.first

			if a_mover_prods_count == 0
				puts "Tengo 0 en mano, eliminamos los detalles del producto"
				prods.destroy_all
				Scheduler::ProductosHelper.cargar_nuevos
				if candidatos.sum(:count_on_hand) == 0
					break
				end
				next
			end

      variants = Hash.new(0)
      variants[prod.stock_item.variant] = [a_mover_prods_count, q].min

			begin
				puts "Moveremos " + variants.to_s + " desde almacen " + prod.stock_item.stock_location.name + " a " + despacho_escogido.name

        stock_transfer = Spree::StockTransfer.create(reference: reference)
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
    		#Scheduler::ProductosHelper::cargar_nuevos
    		return cambiar_items_a_despacho(variant, q, reference)
    		break
    	end

    	Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs

      q -= [a_mover_prods_count, q].min
    end
    #return true
	end

	def cambiar_almacen
		puts "Cambiando de almacen las ordenes listas"

		Spree::Order.where(state: "complete", payment_state: "paid").where.not(shipment_state: "shipped").each do |orden|
			orden.with_lock do
				puts "Analizando order " + orden.number.to_s

				a_mover = {}
				almacen_despacho = Spree::StockLocation.despachos.order(capacidad_maxima: :desc).first

				orden.shipments.each do |shipment|
					capacidad_disponible = almacen_despacho.available_capacity

					shipment.with_lock do
						if shipment.stock_location.proposito != "Despacho"
							shipment.line_items.each do |li|
								li.with_lock do
									variant_li = li.variant
									cantidad_en_shipment = shipment.inventory_units_for(variant_li).sum(:quantity)

									cantidad_en_despachos = variant_li.stock_items.where(stock_location: almacen_despacho).map(&:count_on_hand).reduce(:+).to_i
									cantidad_mover_a_despacho = [cantidad_en_shipment - cantidad_en_despachos, 0].max

									cantidad_efectiva_a_despacho = [capacidad_disponible, cantidad_mover_a_despacho].min
									capacidad_disponible -= cantidad_efectiva_a_despacho
									
									cantidad_efectiva_sacar_de_shipment = [cantidad_en_shipment, cantidad_efectiva_a_despacho + cantidad_en_despachos].min

									puts "Eliminando " + variant_li.sku + " de ship " + shipment.number + " y unidades " + cantidad_efectiva_sacar_de_shipment.to_s
									puts "Cantidad que hay en despacho " + cantidad_en_despachos.to_s + " y se moveran " + cantidad_efectiva_a_despacho.to_s + " a despacho"

									# Sacamos del shipment original
									if cantidad_efectiva_sacar_de_shipment > 0
										orden.contents.remove(variant_li, cantidad_efectiva_sacar_de_shipment, shipment: shipment)

										if a_mover[variant_li].nil?
											a_mover[variant_li] = []
										end
										a_mover[variant_li] << [cantidad_efectiva_sacar_de_shipment, cantidad_efectiva_a_despacho]
									end

								end
							end

							if !shipment.inventory_units.any?
								shipment.destroy!  ## destruimos el shipment
							end
						end
					end
				end

				if !a_mover.empty?
					shipment_despacho = orden.shipments.where.not(state: "shipped").find_by(stock_location: almacen_despacho)
					if shipment_despacho.nil?
						puts "Creando shipment"
						## si no hay shipment de despacho lo creamos
						shipment_despacho = orden.shipments.create(stock_location: almacen_despacho, address: orden.ship_address)
					else
						puts "Shipment ya existia"
					end

					a_mover.each do |key, array|
						acumulado = array.transpose.map(&:sum)
						cantidad_agregar_a_shipment = acumulado[0]
						cantidad_mover_a_despacho = acumulado[1]


						puts "Moviendo " + key.sku + " unidades: " + cantidad_mover_a_despacho.to_s
						# Movemos al almacen de despacho
						if cantidad_mover_a_despacho > 0
							cambiar_items_a_despacho(key, cantidad_mover_a_despacho, "Para crear shipment en almacen de despacho")
						end

						# Agregamos al shipment de despacho
						puts "Agregando " + key.sku + " a shipment " + shipment_despacho.number + " y unidades " + cantidad_agregar_a_shipment.to_s
						if cantidad_agregar_a_shipment > 0
							begin
								orden.contents.add(key, cantidad_agregar_a_shipment, shipment: shipment_despacho)  ## variant, quantity, options

							rescue ActiveRecord::RecordInvalid => e  ## por si tira error, puede que se haya escogido la cantidad mal
								puts e
								shipment_despacho.destroy
								if orden.shipments.empty?
									orden.line_items.each do |li|
										li.delete
									end
									orden.destroy
								end
								Scheduler::ProductosHelper.cargar_nuevos
							end
						end
					end
				end

			end
		end
	end

end
