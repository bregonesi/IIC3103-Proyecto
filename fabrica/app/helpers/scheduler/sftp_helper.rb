module Scheduler::SftpHelper

	def agregar_nuevas_ordenes
		url = ENV['api_oc_url'] + "obtener/"

    j = 0

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

            orden_nueva = Spree::Order.where(number: content_id,
                                             email: 'spree@example.com').first_or_create! do |o|
              j += 1
              puts j.to_s + ": Cargando " + entry.name
              
              variant = Spree::Variant.find_by!(sku: content_sku)
              o.contents.add(variant, content_qty.to_i, {})  ## variant, quantity, options
              o.update_line_item_prices!
              o.create_tax_charge!
              o.next!  # pasamos a address

              o.bill_address = Spree::Address.first
              o.ship_address = Spree::Address.first
              o.next!  # pasamos a delivery

              o.create_proposed_shipments
              o.next!  # pasamos a payment

              payment = o.payments.where(amount: BigDecimal(o.total, 4),
                                         payment_method: Spree::PaymentMethod.where(name: 'Gratis', active: true).first).first_or_create!
              payment.update_columns(state: 'checkout')

              o.confirmation_delivered = true  ## forzamos para que no se envie mail
              o.next!  # pasamos a complete
            end

            if orden_nueva.channel != "ftp"  # si es primera vez que la creamos
							r = HTTParty.get(url + content_id, headers: { 'Content-type': 'application/json' })
							if r.code != 200
								raise "Error en get oc."
							end
							body = JSON.parse(r.body)[0]

              orden_nueva.completed_at = DateTime.strptime((date_ingreso.to_f / 1000).to_s, '%s')
              orden_nueva.channel = "ftp"
							orden_nueva.fechaEntrega = body['fechaEntrega']

	            orden_nueva.save!

              if Time.now() >= orden_nueva.fechaEntrega || body['estado'] == "rechazada" || body['estado'] == "anulada"   ## chequeat q no haya sido ni despachado algo o terminada
                orden_nueva.canceled_by(Spree::User.first)
              end
	          end

            if j == 30
              raise "Botamos por que agregamos maximo 30"
            end

          end # end de inside file
        end # end de if.xml
      end # end de foreach file
    end # end de conexion
  end # end de metodo

end