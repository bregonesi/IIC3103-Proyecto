module Scheduler::SftpHelper

	def agregar_nuevas_ordenes
		url = ENV['api_oc_url'] + "obtener/"

		sftp = Net::SFTP.start(ENV['sftp_ordenes_url'], ENV['sftp_ordenes_login'], password: ENV['sftp_ordenes_psswd'])  ## necesitamos dos conexiones
	  Net::SFTP.start(ENV['sftp_ordenes_url'], ENV['sftp_ordenes_login'], password: ENV['sftp_ordenes_psswd']) do |entries|
    	entries.dir.foreach('/pedidos/') do |entry|
      	if entry.name.include?("xml")
      		date_ingreso = entry.name.split('.xml').join
      		sftp.file.open("/pedidos" + "/" + entry.name, "r") do |f|
            content_id = nil
            content_sku = nil
            content_qty = nil
            while !f.eof?
              content = f.gets
              # obtengo los ids
              if content.include?("id")
                content = content.split('>')[1]
                content = content.split('<')[0]
                content_id = content
              elsif content.include?("sku")
                content = content.split('>')[1]
                content = content.split('<')[0]
                content_sku = content
              elsif content.include?("qty")
                content = content.split('>')[1]
                content = content.split('<')[0]
                content_qty = content
              end
            end

            orden_nueva = SftpOrder.where(oc: content_id).first_or_create! do |o|
              puts "Cargando " + content_id

              r = HTTParty.get(url + content_id, headers: { 'Content-type': 'application/json' })
              if r.code != 200
                raise "Error en get oc."
              end

              body = JSON.parse(r.body)[0]

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
              o.myEstado = body['estado']
              o.serverEstado = body['estado']
              o.created_at = body['created_at']

              if o.serverCantidadDespachada >= o.cantidad
                o.myEstado = "finalizada"
              end
            end
          end # end de inside file
        end # end de if.xml
      end # end de foreach file
    end # end de conexion
  end # end de metodo

end