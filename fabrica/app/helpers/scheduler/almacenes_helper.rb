module Scheduler::AlmacenesHelper

	def mantener_consistencia  ## consiste en ordenar productos por antiguedad en almacenes (en lo posible) y mantenerlos todos ocupados
		# en despacho iran los mas antiguos y se deja un gap de 1000 para cambiar a despachos cuando sea necesario
		# en recepcion se dejan los mas jovenes (probablemente este vacio nomas)
		# en general se deja el resto y se deja un gap de 500 para poder hacer movimientos
		# pulmon solo se deja si recepcion se llena, ningun otro almacen se va a llenar
		despacho = Spree::StockLocation.where(proposito: "Despacho")
		despacho_stock_items = despacho.map(&:stock_items).flatten
		general = Spree::StockLocation.where(proposito: "General")
		general_stock_items = general.map(&:stock_items).flatten
		recepcion = Spree::StockLocation.where(proposito: "Recepcion")
		recepcion_stock_items = recepcion.map(&:stock_items).flatten
		pulmon = Spree::StockLocation.where(proposito: "Pulmon")
		pulmon_stock_items = pulmon.map(&:stock_items).flatten

		despacho.each do |almacen|
			j = almacen.available_capacity
			cap_dis = 1000
			while j > cap_dis
				productos_ordenados = ProductosApi.no_vencidos.order(:vencimiento)
				a_mover = productos_ordenados.where.not(stock_item: despacho_stock_items).group(:vencimiento)  ## quiero limit pero me tira error, asi que lo haremos a la mala

        if a_mover.empty?
        	break
        end

				a_mover_prods = a_mover.each

				prod = a_mover_prods.next

				a_mover_prods_count = a_mover.count[prod.vencimiento]

        variants = Hash.new(0)
        variants[prod.stock_item.variant] = [a_mover_prods_count, j - cap_dis].min

				begin
	        stock_transfer = Spree::StockTransfer.create(reference: "Para tener capacidades 'optimas'")
	        stock_transfer.transfer(prod.stock_item.stock_location,
	                                almacen,
	                                variants)
        rescue ActiveRecord::RecordInvalid => e
      		puts e
      		prod.stock_item.stock_location.stock_items.each do |x|  ## me tira error (como que sincroniza mal), entonces actualizamos todo de nuevo
      			Scheduler::ProductosHelper::cargar_detalles(x)
      		end
      		break
      	end

        Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs

        j -= [a_mover_prods_count, j - cap_dis].min
			end
		end

		general.each do |almacen|
			j = almacen.available_capacity
			cap_dis = 500
			while j > cap_dis
				productos_ordenados = ProductosApi.no_vencidos.order(:vencimiento)
				a_mover = productos_ordenados.where.not(stock_item: despacho_stock_items + general_stock_items).group(:vencimiento)  ## quiero limit pero me tira error, asi que lo haremos a la mala
				
				if a_mover.empty?
        	break
        end
				
				a_mover_prods = a_mover.each

				prod = a_mover_prods.next

				a_mover_prods_count = a_mover.count[prod.vencimiento]


        variants = Hash.new(0)
        variants[prod.stock_item.variant] = [a_mover_prods_count, j - cap_dis].min

        begin
	       	stock_transfer = Spree::StockTransfer.create(reference: "Para tener capacidades 'optimas'")
	       	
	        stock_transfer.transfer(prod.stock_item.stock_location,
	                                almacen,
	                                variants)

        rescue ActiveRecord::RecordInvalid => e
      		puts e
      		prod.stock_item.stock_location.stock_items.each do |x|  ## me tira error (como que sincroniza mal), entonces actualizamos todo de nuevo
      			Scheduler::ProductosHelper::cargar_detalles(x)
      		end
      		break
      	end

        Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs

        j -= [a_mover_prods_count, j - cap_dis].min
			end
		end

	end

	def nuevos_almacenes
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
			    a_new.active = false  ## con esto evitamos que las ordenes se vayan para aca
		    end
			  if new_almacen
			    new_almacen.save
			  end
		  end
		end
	end

	def eliminar_extras
		url = ENV['api_url'] + "bodega/almacenes"

		base = 'GET'
		key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		r = HTTParty.get(url, headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
		
		if r.code != 200
			raise "Error en get almacenes"
		end

	  if JSON.parse(r.body).count != Spree::StockLocation.count - 1  ## si nos eliminaron alguno (-1 por el almacen de backorder)
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