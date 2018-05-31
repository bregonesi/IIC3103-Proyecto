module Scheduler::PaymentHelper

	def marcar_pagadas
		puts "Marcando las pagadas"

		# Aca pagamos las ordenes #
		Spree::Order.where(payment_state: "balance_due").each do |orden_inpaga|
			orden_inpaga.with_lock do
				#if orden_inpaga.payments.first.number == "algo"  # aqui se chequea que coincide el pago
					#orden_inpaga.payment_state = "paid"
					#orden_inpaga.outstanding_balance
					orden_inpaga.payments.where(state: "checkout").each do |orden_inpaga_pagos|
						puts "Marcando payment " + orden_inpaga_pagos.number.to_s + " como pagado"
						orden_inpaga_pagos.send("capture!")  ## con esto se marca como pagado y se registra
					end
					# probablemente tengamos que llamar a la api del profe
					puts "Orden cambia a estado pagada"
				# end
			end
		end
	end

	def pagar_ordenes  # hago esto por si ocupo mas de una funcion pagar
		marcar_pagadas
	end

end
