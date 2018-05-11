module Scheduler::SftpHelper

	def agregar_nuevas_ordenes
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
                # puts content_id
              elsif content.include?("sku")
                content = content.split('>')[1]
                content = content.split('<')[0]
                content_sku = content
                # puts content_sku
              elsif content.include?("qty")
                content = content.split('>')[1]
                content = content.split('<')[0]
                content_qty = content
                # puts content_qty
              end
            end

            orden_nueva = Spree::Order.where(number: content_id,
            																 email: 'spree@example.com').first_or_create! do |o|
              variant = Spree::Variant.find_by!(sku: content_sku)

              o.channel = "ftp"

              o.shipping_address = Spree::Address.first
              o.billing_address = Spree::Address.first

              o.item_total = (content_qty.to_f * variant.price.to_f).to_i
              o.total = o.item_total
              
              o.line_items.new(variant: variant,
              								 quantity: content_qty,
              								 price: o.item_total).save!
            end
            
            if orden_nueva.state != 'complete'
	            orden_nueva.create_proposed_shipments
	            orden_nueva.state = 'complete'
	            orden_nueva.store = Spree::Store.default
	            orden_nueva.completed_at = DateTime.strptime((date_ingreso.to_f / 1000).to_s, '%s')
	            orden_nueva.save!

	            orden_nueva.update_with_updater!
						  payment = orden_nueva.payments.where(amount: BigDecimal(orden_nueva.total, 4),
						                                 			 payment_method: Spree::PaymentMethod.where(name: 'Gratis', active: true).first).first_or_create!

						  payment.update_columns(state: 'checkout')
	          end

          end # end de inside file
        end # end de if.xml
      end # end de foreach file
    end # end de conexion
  end # end de metodo

end