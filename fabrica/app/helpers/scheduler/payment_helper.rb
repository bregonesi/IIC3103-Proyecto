module Scheduler::PaymentHelper

	def marcar_pagadas
		puts "Marcando las pagadas"

		# Aca pagamos las ordenes #
		Spree::Order.where(payment_state: "balance_due").each do |orden_inpaga|
			orden_inpaga.with_lock do
				if orden_inpaga.sftp_order.canal == "b2b"
					factura = Invoice.find_by(originator_type: orden_inpaga.sftp_order.class.name.to_s, originator: orden_inpaga.sftp_order.id.to_i)
					if factura.nil?
						puts "No tenemos factura para la sftp order b2b " + orden_inpaga.sftp_order.id.to_s
						next
					else
						if !(factura.estado == "pagada")
							puts "Factura para sftp order " + orden_inpaga.sftp_order.id.to_s + " no se encuentra pagada."
							next
						end
					end
				end

				orden_inpaga.payments.where(state: "checkout").each do |orden_inpaga_pagos|
					puts "Marcando payment " + orden_inpaga_pagos.number.to_s + " como pagado"
					orden_inpaga_pagos.send("capture!")  ## con esto se marca como pagado y se registra
				end
				puts "Orden cambia a estado pagada"
			end
		end
	end

	def pagar_ordenes  # hago esto por si ocupo mas de una funcion pagar
		marcar_pagadas
	end

	def actualizar_invoices
		puts "Actualizando invoices"

		Invoice.where(estado: "pendiente").each do |inv|
			puts "Actualizando invoice " + inv._id.to_s
			
			factura_request = HTTParty.get(ENV['api_sii_url'] + inv._id.to_s, headers: { 'Content-type': 'application/json'})
			if factura_request.code == 200
				body = JSON.parse(factura_request.body)[0]
				inv.estado = body["estado"]
				inv.save!
			else
				puts "Error en get factura"
				puts factura_request
			end
		end
	end

end
