module Scheduler::ShipmentHelper

	def despachar
    stop_scheduler = false

    Spree::Shipment.where(state: "ready", stock_location: Spree::StockLocation.where(proposito: "Despacho")).each do |shipment|  ## seleccionamos solo los que estan listos y en despacho
      shipment.with_lock do
        orden = shipment.order
        orden.with_lock do
          if orden.payment_state == "paid"  ## hay que pagar primero
            shipment.inventory_units.each do |iu|
              iu.with_lock do
                cantidad_despachar = iu.quantity.to_i - iu.shipped_quantity.to_i
                stock_item_despachar = iu.variant.stock_items.find_by(stock_location: shipment.stock_location)
                Scheduler::ProductosHelper.cargar_detalles(stock_item_despachar)  ## cargamos detalles para ver si se vencieron/aparecieron nuevos
                productos_despachar = Scheduler::ProductosHelper.obtener_lote_antiguo(stock_item_despachar, cantidad=cantidad_despachar)

                j = 0  # contador de cuantos productos han sido despachados
                if productos_despachar.empty?
                  # si no hay productos para despachar entonces es por que
                  # probablemente algo fallo y ya se despacho todo
                  # asi que j = cantidad_despachar
                  j = cantidad_despachar
                end

                productos_shipped = []
                productos_despachar.each do |prod|  ## hay que eliminar producto por producto (si, ineficiente)
                  
                  if orden.sftp_order.nil? || orden.sftp_order.canal == "ftp"  ## hay que utilizar despachar productos
                    oc = "000000000000000000000000"  ## compras por spree
                    if !orden.sftp_order.nil?
                      oc = orden.sftp_order.oc.to_s
                    end

                    base = 'DELETE' + prod.id_api + shipment.address.address1 + iu.line_item.price.to_i.to_s + oc.to_s
                    key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
                    r = HTTParty.delete(ENV['api_url'] + "bodega/stock",
                                        body: {productoId: prod.id_api,
                                               direccion: shipment.address.address1,
                                               precio: iu.line_item.price.to_i,
                                               oc: oc.to_s}.to_json,
                                        headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})

                  elsif orden.sftp_order.canal == "b2b"  ## compras entre grupos, hay que mover stock
                    oc = orden.sftp_order.oc.to_s
                    info_grupo_despacho = $info_grupos.select{|key, hash| hash[:id] == orden.sftp_order.cliente }.first[1]
                    almacen_despacho = info_grupo_despacho[:almacen]
                    if almacen_despacho.nil?
                      puts "No tengo info del almacen de despacho para sftp order " + oc.to_s
                      next
                    end
                    base = 'POST' + prod.id_api + almacen_despacho
                    key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
                    r = HTTParty.post(ENV['api_url'] + "bodega/moveStockBodega",
                                      body: {productoId: prod.id_api,
                                             almacenId: almacen_despacho,
                                             oc: oc.to_s,
                                             precio: iu.line_item.price.to_i}.to_json,
                                      headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
                  else
                    raise "No tenemos como despachar orden"
                  end

                  puts r

                  if r.code == 200
                    j += 1
                    productos_shipped << prod
                    prod.destroy!
                    puts "Despacho de un producto exitoso. Van " + j.to_s + " productos despachados."
                  else
                    puts "Error despachando orden. Error en response code de api. Responde code " + r.code.to_s + "."
                    puts r
                    if r.code == 404 || r.code == 400
                      prod.destroy!
                    end
                  end
                end  # end prod
                iu.shipped_quantity += j
                iu.save!  ## actualizamos lo despachado

                begin
                  Scheduler::ProductosHelper.cargar_detalles(Spree::StockItem.find_by(variant: iu.variant, stock_location: shipment.stock_location))
                rescue NoMethodError => e
                  puts e
                end

                if iu.shipped_quantity >= iu.quantity
                  iu.shipment.ship!

                  #if !iu.order.sftp_order.nil?
                  #  iu.order.sftp_order.myCantidadDespachada += shipped_quantity
                  #  iu.order.sftp_order.save!
                  #end
                  puts "Orden despachada"
                else
                  stop_scheduler = true
                end
              end # end lock iu
            end # end iteracion iu
          end # end if paid
        end # end lock order
      end  # end lock shipment

      if stop_scheduler
        despachar
      end

    end # end shipment
  end

	def despachar_ordenes  # hago esto por si ocupo mas de una funcion shipment
		despachar
	end

end
