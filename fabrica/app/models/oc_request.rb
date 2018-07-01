class OcRequest < ApplicationRecord
	belongs_to :sftp_order
	has_many :ocs_generadas, dependent: :destroy

	def self.por_recibir
		self.por_responder.or(self.where(por_responder: false, aceptado: true, despachado: false))
	end

	def self.por_responder
		self.where(por_responder: true)
	end

	def self.por_generar
		esperando_respuesta = OcRequest.por_responder.joins(:ocs_generadas).where('"ocs_generadas"."estado" = ?', "creada").select('"oc_requests"."id"')
		no_completado_requests = OcRequest.por_responder.left_outer_joins(:ocs_generadas).includes(:ocs_generadas).group(:id).having('count("oc_requests"."id") < 8')
		self.por_responder.where.not(id: esperando_respuesta).where(id: no_completado_requests)
	end

	def cantidad_restante
		cantidad - cantidad_pedida
	end
end
