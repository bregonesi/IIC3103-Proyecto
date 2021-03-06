module Scheduler::OcHelper
	def generar_oc(sftp_order, cantidad, sku=sftp_order.sku)
		puts "Generando oc para sftp order " + sftp_order.oc + " sku " + sku.to_s + " cantidad " + cantidad.to_s

		precio_max = sftp_order.precioUnitario  ## estoy dispuesto a pagar a lo q me compran
		if sku != sftp_order.sku
			variant = Spree::Variant.find_by(sku: sftp_order.sku)
			ingrediente = Spree::Variant.find_by(sku: sku)
			total_ingredientes = variant.recipe.sum(:amount)
			if ingrediente.primary? # siempre deberia ser verdad esto
				ing = variant.recipe.find_by(variant_ingredient: ingrediente)
				precio_max = (ing.amount.to_f / total_ingredientes.to_f) * sftp_order.precioUnitario
				precio_max = precio_max.to_i
				precio_max = [precio_max, ingrediente.cost_price * 1.2].max
			end
		end

		puts "Precio maximo a pagar " + precio_max.to_s

		ocr = sftp_order.oc_requests.where(sku: sku, cantidad: cantidad, despachado: false, created_at: 2.hours.ago..Float::INFINITY).first_or_create! do |o|
			o.precio_maximo = precio_max
		end
	end

	def generar_oc_sistema
		OcRequest.por_generar.each do |oc|
			puts "Generaremos las oc para sftp order " + oc.sftp_order.oc

			grupos_preguntado = oc.ocs_generadas.map(&:grupo)
			info_grupo_keys_shuffle = $info_grupos.keys.shuffle
			info_grupo_keys_shuffle.delete(4)  # 4 es nuestro grupo
			grupo = nil
			while grupo = info_grupo_keys_shuffle.shift do
				if grupos_preguntado.empty? || !grupos_preguntado.include?(grupo)
					break
				end
			end

			if !grupo.nil?
				puts "Veremos si grupo " + grupo.to_s + " tiene stock"

				datos_grupo = $info_grupos[grupo]
				variant = Spree::Variant.find_by(sku: oc.sku)

				errores_stock_request = nil
				begin
					stock_request = HTTParty.get(datos_grupo[:stock_url].to_s,
																			 timeout: 10,
																			 body: { }.to_json,
																			 headers: { 'Content-type': 'application/json' })
				rescue Exception => e # Never do this!
					errores_stock_request = e
				end

				oc_generada = oc.ocs_generadas.where(grupo: grupo).first_or_create! do |o|
					o.cliente = $info_grupos[4][:id]
					o.proveedor = datos_grupo[:id]
					o.sku = oc.sku

					delta = ([oc.sftp_order.fechaEntrega, oc.created_at + 2.hour].min - DateTime.now.utc) / 3.0
					o.fechaEntrega = DateTime.now.utc + delta

					o.cantidad = oc.cantidad_restante
					o.precioUnitario = oc.precio_maximo.to_i
					o.canal = "b2b"
					o.notas = ""
					o.rechazo = ""
					o.anulacion = ""
					o.urlNotificacion = ENV['url_notificacion_oc']
					o.estado = "creada"
				end

				if errores_stock_request.nil?
					if !datos_grupo[:oc_url].empty?
						if stock_request.code == 200
							body = JSON.parse(stock_request.body)
							acepto_precio = false
							hay_stock = false
							body.each do |prod|
								if prod["sku"] == oc.sku
									if prod["price"].to_i <= oc_generada.precioUnitario
										acepto_precio = true
										if prod["available"].to_i > 0
											oc_generada.cantidad = [oc_generada.cantidad, prod["available"].to_i].min
											lote_min = Spree::Variant.find_by(sku: oc_generada.sku)
											if !lote_min.nil?
												lote_min = (lote_min.lote_minimo/1.5).to_i
												oc_generada.cantidad = [oc_generada.cantidad, lote_min].min
											end

											oc_generada.precioUnitario = prod["price"].to_i
											oc_generada.save!

											puts "Grupo tiene " + oc_generada.cantidad.to_s + " uds. Intento crear orden con precio " + oc_generada.precioUnitario.to_s

											hay_stock = true

											## Mandamos oc
											oc_request = HTTParty.put(ENV['api_oc_url'] + "crear",
																								body: { cliente: oc_generada.cliente,
																												proveedor: oc_generada.proveedor,
																												sku: oc_generada.sku,
																												fechaEntrega: oc_generada.fechaEntrega.to_i * 1000,
																												cantidad: oc_generada.cantidad,
																												precioUnitario: oc_generada.precioUnitario,
																												canal: oc_generada.canal,
																												urlNotificacion: oc_generada.urlNotificacion }.to_json,
																								headers: { 'Content-type': 'application/json' })

											puts oc_request
											if oc_request.code == 200
												puts "Orden creada"

												oc.cantidad_pedida += oc_generada.cantidad
												oc.save!

												body = JSON.parse(oc_request.body)
												oc_generada.oc_id = body['_id']
												oc_generada.cantidadDespachada = body['cantidadDespachada'].to_i
												oc_generada.urlNotificacion = body['urlNotificacion']
												oc_generada.created_at = body['created_at']
												oc_generada.notas = "Se crea ya que se cuenta con stock"

											else
												oc_generada.estado = "anulada"
												oc_generada.anulacion = "Se anula ya que no se retorno 200 al crear la oc. Codigo devuelto " + oc_request.code.to_s + " y error " + oc_request.body.to_s
											end
										end
									else
										puts "No hacemos oc por que vende muy alto"
									end

									break
								end
							end
							oc_generada.save!

							notificado = false
							if acepto_precio && hay_stock
								# Le decimos que creamos una oc
								errores_notificar_oc = ""
								begin
									puts "Notifico al grupo"
									if !notificado
										notificado = true
										HTTParty.put(datos_grupo[:oc_url] + oc_generada.oc_id, timeout: 10, body: { }.to_json, headers: { 'Content-type': 'application/json' })
									end
								rescue Exception => e # Never do this!
									notificado = true
									errores_notificar_oc = e
									oc_generada.notas += e.to_s
									oc_generada.save!
								end
							else
								puts "Grupo no tiene stock o vende muy alto"
								oc_generada.estado = "anulada"

								if !acepto_precio
									oc_generada.anulacion = "Se anula ya que grupo vende muy alto"
								else
									oc_generada.anulacion = "Se anula ya que grupo no tiene stock para satisfacer nuesta oc"
								end

								oc_generada.save!
								return generar_oc_sistema
							end
						else
							puts "Return code no es 200"
							oc_generada.estado = "anulada"
							oc_generada.anulacion = "Se anula ya que grupo no responde 200 en su request de stock"
							oc_generada.save!
							return generar_oc_sistema
						end
					else
						puts "No tenemos la url para mandar oc"
						oc_generada.estado = "anulada"
						oc_generada.anulacion = "Se anula ya que no se tiene la url para mandar oc"
						oc_generada.save!
						return generar_oc_sistema
					end
				else
					puts "Error en get stock (de conexion)"
					oc_generada.estado = "anulada"
					oc_generada.anulacion = "Se anula ya que grupo no se pudo conectar con get stock. Error " + errores_stock_request.to_s
					oc_generada.save!
					return generar_oc_sistema
				end
			else
				puts "Ya preguntamos a todos los grupos. Rechazamos solicitud de orden"
			end

		end
	end

	def rechazar_despues_de_5_mins
		# en realidad dejaremos que pasen 7 ya que puede haber desface entre que se crea y se acepta
		OcsGenerada.where(estado: "creada").each do |oc|
			if DateTime.now.utc > oc.created_at + 7.minutes
				puts "Anularemos " + oc.oc_id.to_s

				r = HTTParty.get(ENV['api_oc_url'] + "obtener/" + oc.oc_id.to_s, headers: { 'Content-type': 'application/json' })
				if r.code == 200
					body = JSON.parse(r.body)[0]

					if body['estado'] == "aceptada"  # por si nos aceptaron y no nos dijeron
						oc.estado = "aceptada"
						oc.oc_request.por_responder = false
						oc.oc_request.aceptado = true
						oc.oc_request.save!
						oc.save!
						next
					end
				end

				anulacion = "Se anula ya que no se recibio respuesta en 7 minutos"
				if !oc.oc_id.nil?
					r = HTTParty.delete(ENV['api_oc_url'] + "anular/" + oc.oc_id.to_s,
															body: { anulacion: anulacion }.to_json,
															headers: { 'Content-type': 'application/json' })
					puts r
				end

				if oc.oc_id.nil? || r.code == 200
					if !oc.oc_id.nil?
						body = JSON.parse(r.body)[0]
						oc.cantidadDespachada = body['cantidadDespachada'].to_i
						oc.estado = body['estado']
						oc.rechazo = body['rechazo'] || ""
						oc.anulacion = body['anulacion'] || ""
					end

					if oc.estado == "creada" || oc.estado == "anulada"
						oc.estado = "anulada"

						puts "Quitamos " + oc.cantidad.to_s + " de cantidad pedida"
						oc.oc_request.cantidad_pedida -= oc.cantidad
						oc.oc_request.save!
					end

					if oc.estado == "finalizada" || oc.estado == "rechazada"
						if oc.cantidadDespachada >= oc.cantidad
							if oc.oc_request.cantidad_restante <= 0
								oc.oc_request.por_responder = false
								oc.oc_request.aceptado = true
								oc.oc_request.despachado = true
							else
								oc.oc_request.por_responder = true
								oc.oc_request.aceptado = false
								oc.oc_request.despachado = false
								oc.oc_request.cantidad_pedida -= (oc.cantidad - oc.cantidadDespachada)
							end
						else
							oc.oc_request.por_responder = true
							oc.oc_request.aceptado = false
							oc.oc_request.despachado = false
							oc.oc_request.cantidad_pedida -= (oc.cantidad - oc.cantidadDespachada)
						end
						oc.oc_request.save!
					end
					oc.save!
				else
					puts r
				end

			end
		end
	end

	def actualizar_respuesta_oc_requests
		OcRequest.por_responder.each do |ocr|
			rechazadas = ocr.ocs_generadas.where('"ocs_generadas"."estado" = ? OR "ocs_generadas"."estado" = ? OR "ocs_generadas"."estado" = ?', "anulada", "rechazada", "finalizada").count
			if rechazadas >= 8
				puts "Cambiando por responder de orden " + ocr.sftp_order.to_s
				ocr.por_responder = false
				ocr.save!
			end
		end
	end

	def volver_a_estado_creada
		## es por si las que dejamos en preaceptadas tienen que volver a aceptadas ya que no pudimos satisfacer mediante ocs
		SftpOrder.preaceptadas.each do |order|
			order.with_lock do
				if !order.oc_requests.empty? && order.fabricar_requests.empty?
					cambiar = true
					order.oc_requests.each do |ocr|
						if ocr.por_responder != false || ocr.aceptado != false || ocr.despachado != false
							cambiar = false
							break
						end
					end
					if cambiar
						puts "Cambiando estado de sftporder " + order.oc
						order.myEstado = order.serverEstado
						order.save!
					end
				else
					if order.fabricar_requests.empty?
						puts "Cambiando estado de sftporder " + order.oc
						order.myEstado = order.serverEstado
						order.save!
					end
				end
			end
		end
	end

	def actualizar_aceptadas
		OcsGenerada.where(estado: "aceptada").each do |oc|
			puts "Actualizando aceptada de oc b2b " + oc.oc_id.to_s

			r = HTTParty.get(ENV['api_oc_url'] + "obtener/" + oc.oc_id.to_s, headers: { 'Content-type': 'application/json' })
			if r.code == 200
				body = JSON.parse(r.body)[0]

				if body.nil?
					puts "ERROR: Obtener oc retorno vacio"
					next
				end
				
				oc.cantidadDespachada = body['cantidadDespachada']
				oc.estado = body['estado']
				oc.rechazo = body['rechazo'] || ""
				oc.anulacion = body['anulacion'] || ""

				# Pago factura #
				factura = Invoice.find_by(originator_type: oc.class.name.to_s, originator: oc.id.to_i, estado: "pendiente")
				if !factura.nil?
					proveedor = factura.proveedor
					info_grupo_despacho = $info_grupos.select{|key, hash| hash[:id] == proveedor }.first[1]
					cuenta_transferir = info_grupo_despacho[:id_banco]

					# Transfiero #
					transferencia = Transferencium.where(originator_type: oc.class.name.to_s, originator_id: oc.id.to_i).first_or_create! do |t|
						t.origen = $info_grupos[4][:id_banco]
						t.destino = cuenta_transferir
						t.monto = factura.total

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

					# Marco como pagada #
					factura_request = HTTParty.post(ENV['api_sii_url'] + "pay",
																					body: {id: factura._id}.to_json,
																					headers: { 'Content-type': 'application/json'})
	
					puts factura_request

					if factura_request.code == 200
						body = JSON.parse(factura_request.body)[0]
						factura.estado = body["estado"]
						factura.save!
					else
						puts "Error en pay factura"
						puts factura_request
					end
				end

				if oc.cantidadDespachada >= oc.cantidad
					oc.estado = "finalizada"

					if oc.oc_request.cantidad_restante <= 0
						oc.oc_request.por_responder = false
						oc.oc_request.aceptado = true
						oc.oc_request.despachado = true
					else
						oc.oc_request.por_responder = true
						oc.oc_request.aceptado = false
						oc.oc_request.despachado = false
					end
					oc.oc_request.save!
				else
					if oc.fechaEntrega + 10.minutes < DateTime.now.utc  # si se vencio (le doy 10 mins mas)
						oc.estado = "finalizada"
						oc.oc_request.por_responder = true
						oc.oc_request.aceptado = false
						oc.oc_request.despachado = false
						oc.oc_request.cantidad_pedida -= (oc.cantidad - oc.cantidadDespachada)
						oc.oc_request.save!

						# Rechazo factura #
						factura = Invoice.find_by(originator_type: oc.class.name.to_s, originator: oc.id.to_i)
						if !factura.nil?
							factura_request = HTTParty.post(ENV['api_sii_url'] + "reject", body: {id: factura._id, motivo: "Se vencio la oc" }.to_json, headers: { 'Content-type': 'application/json'})
			
							puts factura_request

							if factura_request.code == 200
								body = JSON.parse(factura_request.body)[0]
								factura.estado = body["estado"]
								factura.save!
							else
								puts "Error en pay factura"
								puts factura_request
							end
						end
					end
				end

				oc.save!
			end
		end
	end

end