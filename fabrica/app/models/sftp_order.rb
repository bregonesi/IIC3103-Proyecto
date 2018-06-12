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
		((SftpOrder.aceptadas.where(canal: "ftp").count + SftpOrder.preaceptadas.where(canal: "ftp").count + SftpOrder.finalizadas.where(canal: "ftp").count).to_f / SftpOrder.where(canal: "ftp").count.to_f).to_f
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

	def puedo_pedir_por_oc(cantidad)  ## si ya pedi cantidad no puedo volver a pedir lo mismo aun que me rechazen, o si me estan despachando tampoco puedo pedir de ese sku
		self.oc_requests.where(sku: self.sku, cantidad: cantidad, despachado: false).empty? && self.oc_requests.where(sku: self.sku, aceptado: true, despachado: false).empty?
	end

	def faltante
		self.cantidad - self.myCantidadDespachada
	end
end
