module Scheduler::OcHelper
	def generar_oc(sftp_order, cantidad)
		puts "Generando oc para sftp order " + sftp_order.oc + " cantidad " + cantidad.to_s
		sftp_order.oc_requests.where(sku: sftp_order.sku, cantidad: cantidad, despachado: false).first_or_create!
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

				stock_request = HTTParty.get(datos_grupo[:stock_url].to_s,
																		 body: { }.to_json,
																		 headers: { 'Content-type': 'application/json' })

				oc_generada = oc.ocs_generadas.where(grupo: grupo).first_or_create! do |o|
					o.cliente = $info_grupos[4][:id]
					o.proveedor = datos_grupo[:id]
					o.sku = oc.sku
					o.fechaEntrega = oc.sftp_order.fechaEntrega
					o.cantidad = oc.cantidad
					o.precioUnitario = variant.price.to_i
					o.canal = "b2b"
					o.notas = ""
					o.urlNotificacion = ENV['url_notificacion_oc']
					o.estado = "creada"
				end

				if stock_request.code == 200
					body = JSON.parse(stock_request.body)
					hay_stock = false
					body.each do |prod|
						if prod["sku"] == oc.sku
							if prod["available"].to_i >= oc.cantidad.to_i
								puts "Grupo si tiene stock. Intento crear orden"

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

									# decirle al wn que cree una orden

									body = JSON.parse(oc_request.body)

									oc_generada.oc_id = body['_id']
									oc_generada.cantidadDespachada = body['cantidadDespachada'].to_i
									oc_generada.urlNotificacion = body['urlNotificacion']
									oc_generada.created_at = body['created_at']
									oc_generada.notas = "Se acepta ya que se cuenta con stock"

								else
									oc_generada.estado = "anulada"
									oc_generada.notas = "Se anula ya que no se retorno 200 al crear la oc. Codigo devuelto " + oc_request.code.to_s + " y error " + oc_request.body.to_s
								end
							end
							break
						end
					end
					oc_generada.save!

					if !hay_stock
						puts "Grupo no tiene stock"
						oc_generada.estado = "anulada"
						oc_generada.notas = "Se anula ya que grupo no tiene stock para satisfacer nuesta oc"
						oc_generada.save!
						return generar_oc_sistema
					end
				else
					puts "Return code no es 200"
					oc_generada.estado = "anulada"
					oc_generada.notas = "Se anula ya que grupo no responde 200 en su request de stock"
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

				r = HTTParty.post(ENV['api_oc_url'] + "anular/" + oc.oc_id.to_s,
													body: { anulacion: "Se anula ya que pasaron mas de 7 minutos desde que se creo." }.to_json,
													headers: { 'Content-type': 'application/json' })
				puts r
				if r.code == 200
					body = JSON.parse(r.body)[0]
					oc.cantidadDespachada = body['cantidadDespachada'].to_i
					oc.estado = "anulada"
					oc.notas += "Se anula ya que pasaron mas de 7 minutos desde que se creo. "
					oc.save!
				else
					puts r
				end

			end
		end
	end

	def actualizar_respuesta_oc_requests
		OcRequest.por_responder.each do |ocr|
			rechazadas = ocr.ocs_generadas.where('"ocs_generadas"."estado" = "anulada" OR "ocs_generadas"."estado" = "rechazada"').count
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
			if !order.oc_requests.empty?
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