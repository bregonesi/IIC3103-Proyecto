class EndpointController < ApplicationController
  include ApplicationHelper

	skip_before_action :verify_authenticity_token

	def recibir_oc
		id_order = params[:id]
		puts "Recibo nueva oc " + id_order.to_s

		r = HTTParty.get(ENV['api_oc_url'] + "obtener/" + id_order.to_s, headers: { 'Content-type': 'application/json' })
		if r.code != 200
			render json: r.body, :status => 400
			return
		end

		orden_nueva = OrdenCompra.where(_id: id_order.to_s).first_or_create! do |o|
			puts "Cargando orden " + id_order.to_s

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
			o.notas = body['notas'] || ""
			o.rechazo = body['rechazo'] || ""
			o.anulacion = body['anulacion'] || ""
			o.urlNotificacion = body['urlNotificacion'] || ""
			o.created_at = body['created_at']
			o.updated_at = body['updated_at']
		end

		if orden_nueva.estado != "creada"
			orden_nueva.notas += "No se acepta ya que no se encuentra en estado creada"
			orden_nueva.save!
			render json: { error: "Orden " + orden_nueva._id + " no esta en estado creada. Estado " + orden_nueva.estado.to_s }, :status => 400
			return
		end

		if orden_nueva.canal != "b2b"
			orden_nueva.notas += "No se acepta ya que no es orden b2b"
			orden_nueva.save!
			render json: { error: "Orden " + orden_nueva._id + " no es b2b. Canal " + orden_nueva.canal.to_s }, :status => 400
			return
		end

		if orden_nueva.urlNotificacion.empty?
			orden_nueva.notas += "No se acepta ya que no hay url notificacion"
			orden_nueva.save!
			render json: { error: "Orden " + orden_nueva._id + " no tiene url notificacion" }, :status => 400
			return
		end

		producto = Spree::Variant.find_by(sku: orden_nueva.sku)

		if orden_nueva.fechaEntrega > DateTime.now.utc - 10.minutes && producto.cantidad_api >= orden_nueva.cantidad && orden_nueva.acepto?
			#acepto
			puts "Marcando " + orden_nueva._id.to_s + " como aceptada"

			r = HTTParty.post(ENV['api_oc_url'] + "recepcionar/" + orden_nueva._id.to_s,
												body: { }.to_json,
												headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]
				orden_nueva.notas += "Si funciono aceptar al profe. "
				orden_nueva.estado = "aceptada"
				orden_nueva.save!

				SftpOrder.where(oc: orden_nueva._id).first_or_create! do |o|
          o.cliente = body['cliente']
          o.proveedor = body['proveedor']
          o.sku = body['sku']
          o.fechaEntrega = body['fechaEntrega']
          o.cantidad = body['cantidad']
          o.myCantidadDespachada = body['cantidadDespachada']
          o.serverCantidadDespachada = body['cantidadDespachada']
          o.precioUnitario = body['precioUnitario']
          o.canal = body['canal']
          o.notas = body['notas']
          o.rechazo = body['rechazo']
          o.anulacion = body['anulacion']
          o.urlNotificacion = body['urlNotificacion']
          o.myEstado = "aceptada"
          o.serverEstado = "aceptada"
          o.created_at = body['created_at']

          if o.serverCantidadDespachada >= o.cantidad
            o.myEstado = "finalizada"
          end
				end
			else
				orden_nueva.notas += "No funciono aceptar al profe. "
				orden_nueva.save!
				render json: { error: "Fallo al aceptar al profesor. Error: " + r.body.to_s }, :status => 400
				return
			end

			errores_notificacion_oc = ""
			notification = ""
			begin
				notification = HTTParty.post(orden_nueva.urlNotificacion, body: { status: "accept" }.to_json, headers: { 'Content-type': 'application/json' })
			rescue Exception => e # Never do this!
				errores_notificacion_oc = e
			end

			if errores_notificacion_oc.empty? && notification.code == 204
				body = JSON.parse(r.body)[0]
				orden_nueva.notas = "Si funciono aceptar al compañero. "
				orden_nueva.save!
			else
				orden_nueva.notas = "No funciono aceptar al compañero. " + errores_notificacion_oc.to_s + notification.to_s
				orden_nueva.save!
				render json: { error: "Fallo al enviar notificacion. Error: " + errores_notificacion_oc.to_s + notification.to_s }, :status => 400
				return
			end

		else
			#rechazo
			puts "Marcando " + orden_nueva._id.to_s + " como rechazada"

			if !(orden_nueva.fechaEntrega > DateTime.now.utc - 10.minutes)
				orden_nueva.rechazo = "Orden vencida o vence pronto"
			elsif !(producto.cantidad_api >= orden_nueva.cantidad)
				orden_nueva.rechazo = "No tengo stock"
			elsif !(OrdenCompra.aceptadas_de_cliente(self.cliente).count.to_f / OrdenCompra.aceptadas.count.to_f) <= 0.7)
				orden_nueva.rechazo = "Mas del 70% de mis ordenes aceptadas son tuyas. Tengo que rechazar."
			elsif !(OrdenCompra.cantidad_maxima_aceptar_de_cliente(orden_nueva.cliente) > OrdenCompra.aceptadas_de_cliente(orden_nueva.cliente).count)
				orden_nueva.rechazo = "Necesito trato justo. Tu tambien me tienes que aceptar."
			else
				orden_nueva.rechazo = "Se rechazo por error"
			end

			r = HTTParty.post(ENV['api_oc_url'] + "rechazar/" + orden_nueva._id.to_s,
												body: { rechazo: orden_nueva.rechazo }.to_json,
												headers: { 'Content-type': 'application/json' })

			if r.code == 200
				body = JSON.parse(r.body)[0]
				orden_nueva.notas += "Si funciono rechazo profe. "
				orden_nueva.estado = "rechazada"
			else
				orden_nueva.notas += "No funciono rechazo profe. "
			end

			errores_notificacion_oc = ""
			notification = ""
			begin
				notification = HTTParty.post(orden_nueva.urlNotificacion, body: { status: "reject" }.to_json, headers: { 'Content-type': 'application/json' })
			rescue Exception => e # Never do this!
				errores_notificacion_oc = e
			end

			if errores_notificacion_oc.empty? && notification.code == 204
				body = JSON.parse(r.body)[0]
				orden_nueva.notas = "Si funciono el rechazo compañero. "
			else
				orden_nueva.notas = "No funciono el rechazo compañero. Error " + errores_notificacion_oc.to_s + notification.to_s
				orden_nueva.save!
				render json: { error: "Fallo al enviar notificacion. Error: " + errores_notificacion_oc.to_s + notification.to_s }, :status => 400
				return
			end

			orden_nueva.save!
		end
		render json: orden_nueva, :status => 200

	end

	def respuesta_oc
		#render json: {}, status: 204
		#return

		oc = params[:id]
		status = params[:status]
		oc_generada = OcsGenerada.find_by(oc_id: oc)
		if oc_generada.nil?
			render json: { error: "Oc " + oc.to_s + " no encontrada" }, :status => 400
			return
		end

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
