module Scheduler::SftpHelper

	def agregar_nuevas_ordenes

		dm = "integradev.ing.puc.cl"
		flogin = "grupo4"
		fpasswd = "1ccWcVkAmJyrOfA"


	  sftp = Net::SFTP.start(dm, flogin, password: fpasswd) do |entries|
    	entries.dir.foreach('/pedidos/') do |entry|
      	if entry.name.include?("xml")
      		sftp2.file.open("/pedidos" + "/" + entry.name, "r") do |f|
          
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


            orden_nueva = Spree::Order.where(
              number: content_id,
              email: 'spree@example.com'
            ).first_or_create! do |o|
              # o.item_total = 0
              # o.adjustment_total = 0
              # o.total = 0
              o.shipping_address = Spree::Address.first
              o.billing_address = Spree::Address.last
              o.state = 'confirm'
              o.store = Spree::Store.default
              o.completed_at = Time.current - 1.day
              # o.line_items.new(
              # variant: Spree::Variant.find_by!(id: 1),
              # quantity: content_qty,
              # price: 0
              # ).save!
            end
            orden_nueva.save!

          end # end de inside file
        end # end de if.xml
      end # end de foreach file
    end # end de conexion
  end # end de metodo

end