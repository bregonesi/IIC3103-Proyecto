class EndpointController < ApplicationController
	skip_before_action :verify_authenticity_token

	def recibir_oc
		oc = params[:id]
		puts "recibo nueva oc " + oc.to_s
		#if tengo stock disponible
			#acepto
		#else
			#rechazo
		#end
	end

	def respuesta_oc
		oc = params[:id]
		status = params[:status]
		puts "recibo notificacion oc " + oc.to_s
		puts "y de status " + status.to_s
		#ver cual es la oc q me aceptaron
		#marcarla como aceptada y a considerar fabrique
	end

  private
    def endpoint_params
      params.require(:endpoint).permit(:status)
    end
end
