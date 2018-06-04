class EndpointController < ApplicationController
  include ApplicationHelper

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
		oc_generada = OcsGenerada.find_by(oc_id: oc)
		if !oc_generada.nil?
			if status == "accept" && oc_generada.estado == "creada"
				oc_generada.estado = "aceptada"
				oc_generada.oc_request.por_responder = false
				oc_generada.oc_request.aceptado = true
				oc_generada.oc_request.save!

				# se supone que esto lo hace el otro grupo, pero forzamos a que si no lo hizo lo hagamos nosotros
				HTTParty.post(ENV['api_oc_url'] + "recepcionar/" + oc.to_s, body: { }.to_json, headers: { 'Content-type': 'application/json' })
			elsif status == "reject" && oc_generada.estado == "creada"
				oc_generada.estado = "rechazada"

				# se supone que esto lo hace el otro grupo, pero forzamos a que si no lo hizo lo hagamos nosotros
				HTTParty.post(ENV['api_oc_url'] + "rechazar/" + oc.to_s, body: { rechazo: "Me llego notificacion de rechazo desde ip " + ip2long(request.remote_ip).to_s }.to_json, headers: { 'Content-type': 'application/json' })
			end
			oc_generada.save!
		end
		render json: {}, status: 204
	end


	private
		def endpoint_params
			params.require(:endpoint).permit(:status)
		end

end
