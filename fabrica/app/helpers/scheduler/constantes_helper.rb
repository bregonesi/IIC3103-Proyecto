module Scheduler::ConstantesHelper

	def set_hook
		puts "Viendo si esta bien seteado hook."

		url = ENV['api_url'] + "bodega/hook"
		hook_url = 'http://integra4.ing.puc.cl/hook'

		base = 'GET'
		key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		r = HTTParty.get(url, headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook

		if r.code == 200
		  if JSON.parse(r.body)["url"] != hook_url
		    print "Cambio hook.\n"

		    base = 'DELETE'
		    key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		    HTTParty.delete(url,
		                    body: {}.to_json,  # empty json
		                    headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook

		    base = 'PUT' + hook_url
		    key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		    HTTParty.put(url,
		                 body: {url: hook_url}.to_json,
		                 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook
		  else
		    print "Hook no cambio. No seteamos nuevo hook.\n"
		  end
		else
		  print "Error. Response code not 200.\n"
		end
	end

	def api_cuenta_banco
		puts "Viendo si esta bien seteado la cuenta banco api."
		
		url = ENV['api_url'] + "bodega/fabrica/getCuenta"

		base = 'GET'
		key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
		r = HTTParty.get(url, headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook

		if r.code == 200
			cuenta = JSON.parse(r.body)["cuentaId"]
			store = Spree::Store.first
		  if store.cuenta_banco.nil? || store.cuenta_banco != cuenta
		  	store.cuenta_banco = cuenta
		  	store.save!
		    print "Cambio cuenta.\n"
		  else
		    print "Cuenta no cambio.\n"
		  end
		else
		  print "Error. Response code not 200.\n"
		end
	end

end