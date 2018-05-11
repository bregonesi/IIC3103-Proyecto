module Scheduler::AlmacenesHelper

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