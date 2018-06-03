class EndpointController < ApplicationController
	skip_before_action :verify_authenticity_token

	def recibir_oc

		id_order = params[:id]
		puts "recibo nueva oc " + id_order.to_s

		orden_nueva = OrdenCompra.where(_id: id_order).first_or_create! do |o|
			puts "Cargando orden " + id_order.to_s

			r = HTTParty.get(ENV['api_oc_url'] + "obtener/" +
				id_order.to_s, headers: { 'Content-type': 'application/json' })
			if r.code != 200
				json_p << {:error => "Error get api"}
				render json: json_p, :status => 400
			end

			body = JSON.parse(r.body)[0]

			o._id = id_order
			o.cliente = body['cliente']
			o.proveedor = body['proveedor']
			o.sku = body['sku']
			o.fechaEntrega = body['fechaEntrega']
			o.cantidad = body['cantidad']
			o.cantidadDespachada = body['cantidadDespachada']
			o.precioUnitario = body['precioUnitario']
			o.canal = body['canal']
			o.estado = body['estado']
			o.notas = body['notas']
			o.rechazo = body['rechazo']
			o.anulacion = body['anulacion']
			o.urlNotificacion = body['urlNotificacion']
			o.created_at = body['created_at']
			o.updated_at = body['updated_at']
		end

		producto = Spree::Product.find_by(sku: orden_nueva.sku)

		if producto.cantidad_disponible >= orden_nueva.cantidad && orden_nueva.estado == "creada"
			#acepto
			puts "Marcando " + orden_nueva._id.to_s + " como aceptada"


			r = HTTParty.post(orden_nueva.urlNotificacion,
												body: { status: "accept" }.to_json,
												headers: { 'Content-type': 'application/json' })

			if r.code == 204
				body = JSON.parse(r.body)[0]
				orden_nueva.notas = "Si funciono aceptar al compañero. "
				orden_nueva.save!
			else
				orden_nueva.notas = "No funciono aceptar al compañero. "
				orden_nueva.save!
				return
			end

			r = HTTParty.post(ENV['api_oc_url'] + "recepcionar/" + orden_nueva._id.to_s,
												body: { id: orden_nueva._id.to_s }.to_json,
												headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]
				orden_nueva.notas += "Si funciono aceptar al profe. "
			else
				orden_nueva.notas += "No funciono aceptar al profe. "
			end

		else
			#rechazo
			puts "Marcando " + orden_nueva._id.to_s + " como rechazada"

			r = HTTParty.post(orden_nueva.urlNotificacion,
												body: { status: "reject" }.to_json,
												headers: { 'Content-type': 'application/json' })
			if r.code == 204
				body = JSON.parse(r.body)[0]
				orden_nueva.rechazo = "No hay stock"
				orden_nueva.notas = "Si funciono el rechazo compañero. "
			else
				orden_nueva.notas = "No funciono el rechazo compañero. "
			end
			r = HTTParty.post(ENV['api_oc_url'] + "rechazar/" + orden_nueva._id.to_s,
												body: { rechazo: orden_nueva.rechazo }.to_json,
												headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]
				orden_nueva.notas += "Si funciono rechazo profe. "
			else
				orden_nueva.notas += "No funciono rechazo profe. "
			end
			orden_nueva.save!
		end

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
