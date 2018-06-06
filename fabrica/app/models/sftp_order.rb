class SftpOrder < ApplicationRecord
	has_many :orders, class_name: 'Spree::Order', dependent: :destroy
	has_many :fabricar_requests, dependent: :destroy
	has_many :oc_requests, dependent: :destroy

	def self.creadas
		SftpOrder.where(myEstado: 'creada')
	end

	def self.aceptadas
		SftpOrder.where(myEstado: 'aceptada')
	end

	def self.preaceptadas
		SftpOrder.where(myEstado: 'preaceptada')
	end

	def self.finalizadas
		SftpOrder.where(myEstado: 'finalizada')
	end

	def self.tasa_aceptadas
		((SftpOrder.aceptadas.count + SftpOrder.preaceptadas.count + SftpOrder.finalizadas.count).to_f / SftpOrder.count.to_f).to_f
	end

	def self.acepto?(tasa_min=0.65)
		SftpOrder.count == 0 || SftpOrder.tasa_aceptadas < tasa_min
	end

	def self.vencidas
		SftpOrder.where(fechaEntrega: Time.at(0)..DateTime.now.utc)
	end

	def vencida?
		self.fechaEntrega < DateTime.now.utc
	end

	def self.vigentes
		SftpOrder.where(fechaEntrega: DateTime.now.utc..Float::INFINITY)
	end

	def vigente?
		self.fechaEntrega >= DateTime.now.utc
	end

	def puedo_pedir_por_oc(cantidad)  ## si ya no pedi (independiente si me rechazaron o esta por llegar)
		self.oc_requests.where(sku: self.sku, cantidad: cantidad, despachado: false).empty?
	end

	def faltante
		self.cantidad - self.myCantidadDespachada
	end
end
