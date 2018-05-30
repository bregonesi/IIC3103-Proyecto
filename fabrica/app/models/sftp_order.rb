class SftpOrder < ApplicationRecord

	def self.aceptadas
		SftpOrder.where(myEstado: 'aceptada').count
	end

	def self.acepto?
		SftpOrder.count == 0 || SftpOrder.aceptadas / SftpOrder.count <= 0.6
	end

	def self.vencidas
		SftpOrder.where(fechaEntrega: Time.at(0)..DateTime.now)
	end

	def self.vencida?(order)
		order.fechaEntrega < DateTime.now
	end
end
