module Scheduler::AlmacenesHelper

	def mantener_consistencia  ## consiste en ordenar productos por antiguedad en almacenes (en lo posible) y mantenerlos todos ocupados
		puts "Mantener consistencias ejecutandose"
		# en despacho iran los mas antiguos y se deja un gap de 1000 para cambiar a despachos cuando sea necesario
		# en recepcion se dejan los mas jovenes (probablemente este vacio nomas)
		# en general se deja el resto y se deja un gap de 500 para poder hacer movimientos
		# pulmon solo se deja si recepcion se llena, ningun otro almacen se va a llenar
		despacho = Spree::StockLocation.where(proposito: "Despacho")
		general = Spree::StockLocation.where(proposito: "General")
		recepcion = Spree::StockLocation.where(proposito: "Recepcion")
		pulmon = Spree::StockLocation.where(proposito: "Pulmon")

		# esperado = [mover a stock, gap, excluir]
		# dejare un gap de 1500 en despacho por errores del profe
		#esperado = [[despacho, 1500, []], [general, 500, [despacho]]]
		esperado = [[general, 500, [despacho]]]

		esperado.each do |entry|
			cap_dis = entry[1]

			entry[0].each do |almacen|
				j = almacen.available_capacity
				ignorar = []
				while j > cap_dis
					productos_ordenados = ProductosApi.no_vencidos.order(:vencimiento)
					a_mover = productos_ordenados.where.not(stock_item: (entry[0] + entry[2].flatten).map(&:stock_items).flatten)
					a_mover_groupped = a_mover.group(:stock_item_id, :vencimiento).count(:id)  # todo hay groups y where denuevo ya que postgres tira error
					
		      if a_mover.empty?
		      	break
		      end

					puts "Cambiando a " + almacen.proposito + " (" + almacen.name + "), cap dis " + cap_dis.to_s

					todos_ignorados = true
					a_mover_stock_item = nil
					a_mover_fecha = nil
					a_mover_prods_count = nil
					a_mover_groupped.each do |a_mover_datos|
						if !ignorar.include?([a_mover_datos[0][0], a_mover_datos[0][1]])
							a_mover_stock_item = a_mover_datos[0][0]
							a_mover_fecha = a_mover_datos[0][1]
							a_mover_prods_count = a_mover_datos[1]
							todos_ignorados = false
							break
						end
					end

					if todos_ignorados
						break
					end

					prods = productos_ordenados.where(stock_item: a_mover_stock_item, vencimiento: a_mover_fecha)
					prod = prods.first

					por_despachar = 0
					prod.stock_item.stock_location.shipments.where.not(state: "canceled").each do |prod_ship|  ## muestra todas las ordenes por despachar del stock location
						if prod_ship.order.completed?  ## solo si esta completado (no se dejo la compra a medio camino)
							prod_ship.inventory_units.where(variant: prod.stock_item.variant, state: "on_hand").each do |iu|
								por_despachar += iu.quantity - iu.shipped_quantity
							end
						end
					end
					puts "Por despachar " + por_despachar.to_s
					a_mover_prods_count -= por_despachar

					cantidad_en_almacen = prod.stock_item.count_on_hand  ## por si estamos recibiendo

	        variants = Hash.new(0)
	        variants[prod.stock_item.variant] = [a_mover_prods_count, j - cap_dis, cantidad_en_almacen].min

	        if variants[prod.stock_item.variant] == 0  ## no hay nada que mover
	        	ignorar << [a_mover_stock_item, a_mover_fecha]
	        	next
	        end

					begin
						puts "Moveremos " + variants.to_s + " desde almacen " + prod.stock_item.stock_location.name + " a " + almacen.name

		        stock_transfer = Spree::StockTransfer.create(reference: "Para tener capacidades 'optimas'")
		        stock_transfer.transfer(prod.stock_item.stock_location,
		                                almacen,
		                                variants)
	        rescue ActiveRecord::RecordInvalid => e  ## por si tira error (no esta sincronizado)
	      		puts e
	      		stock_transfer.destroy
						prods.destroy_all
	      		prod.stock_item.stock_location.stock_items.each do |x|
	      			Scheduler::ProductosHelper::cargar_detalles(x)
	      		end
	      		break
	      	end

	        Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs

	        j -= [a_mover_prods_count, j - cap_dis, cantidad_en_almacen].min
				end
			end
		end
	end

	def nuevos_almacenes
		puts "Chequeando si hay nuevos almacenes"

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
		  	nombre = Spree::StockLocation.count > 0 ? Spree::StockLocation.last.name.split(" ")[1].to_i + 1 : 1
			  new_almacen = Spree::StockLocation.where(name: 'Almacen ' + nombre.to_s,
			                                           address1: 'Av. Vicuña Mackenna 4860',
			                                           city: 'Santiago',
			                                           zipcode: '7820436',
			                                           country: Spree::Country.find_by(iso: 'CL'),
			                                           state: Spree::Country.find_by(iso: 'CL').states.find_by(abbr: 'RM')
			                                          ).first_or_create! do |a_new|
			    a_new.admin_name = almacen['_id']
			    
			    proposito = "General"
			    if almacen['recepcion']
			      proposito = "Recepcion"
			    elsif almacen['despacho']
			      proposito = "Despacho"
			    elsif almacen['pulmon']
			      proposito = "Pulmon"
			    end
			    a_new.proposito = proposito
			    a_new.capacidad_maxima = almacen['totalSpace']
		    end
			  if new_almacen
			    new_almacen.save
			  end
		  end
		end
	end

	def eliminar_extras
		puts "Chequeando si eliminaron almacenes"

		url = ENV['api_url'] + "bodega/almacenes"

		base = 'GET'
		key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		r = HTTParty.get(url, headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
		
		if r.code != 200
			raise "Error en get almacenes"
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
	end

end
