class SftpOrder < ApplicationRecord
	has_many :fabricar_requests

	def self.creadas
		SftpOrder.where(myEstado: 'creada')
	end

	def self.aceptadas
		SftpOrder.where(myEstado: 'aceptada')
	end

	def self.preaceptadas
		SftpOrder.where(myEstado: 'preaceptada')
	end

	def self.tasa_aceptadas
		((SftpOrder.aceptadas.count + SftpOrder.preaceptadas.count).to_f / SftpOrder.count.to_f).to_f
	end

	def self.acepto?(tasa_min=0.6)
		SftpOrder.count == 0 || SftpOrder.tasa_aceptadas < tasa_min
	end

	def self.vencidas
		SftpOrder.where(fechaEntrega: Time.at(0)..DateTime.now)
	end

	def self.vencida?(order)
		order.fechaEntrega < DateTime.now
	end
end
