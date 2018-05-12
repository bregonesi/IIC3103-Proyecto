module Scheduler::ShipmentHelper

	def despachar
    url = ENV['api_url'] + "bodega/stock"
    stop_scheduler = false
    
    Spree::Shipment.where(state: "ready", stock_location: Spree::StockLocation.where(proposito: "Despacho").map(&:id)).each do |shipment|  ## seleccionamos solo los que estan listos y en despacho
      shipment.with_lock do
        if shipment.order.payment_state == "paid"  ## hay que pagar primero
          shipment.inventory_units.each do |iu|
            iu.with_lock do
              cantidad_despachar = iu.quantity.to_i - iu.shipped_quantity.to_i
              productos_despachar = Scheduler::ProductosHelper.obtener_lote_antiguo(
                                      Spree::StockItem.find_by(variant: iu.variant, stock_location: shipment.stock_location),
                                      cantidad=cantidad_despachar)

              j = 0  # contador de cuantos productos han sido despachados
              productos_despachar.each do |prod|  ## hay que eliminar producto por producto (si, ineficiente)
                #base = 'DELETE' + prod['_id'].to_s + inventario_para_despachar.shipment.address.address1 + inventario_para_despachar.line_item.price.to_i.to_s + inventario_para_despachar.order.number.to_s
                base = 'DELETE' + prod.id_api + shipment.address.address1 + iu.line_item.price.to_i.to_s + shipment.order.number
                key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
                r = HTTParty.delete(url,
                                    body: {productoId: prod.id_api,
                                           direccion: shipment.address.address1,
                                           precio: iu.line_item.price.to_i,
                                           oc: shipment.order.number.to_s}.to_json,
                                    headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
                #puts r

                if r.code == 200
                  j += 1
                  puts "Despacho de un producto exitoso. Van " + j.to_s + " productos despachados."
                else
                  puts "Error despachando orden. Error en response code de api. Responde code " + r.code.to_s + "."
                end
              end  # end prod
              iu.shipped_quantity += j
              iu.save!  ## actualizamos lo despachado

              if iu.shipped_quantity >= iu.quantity
                iu.shipment.ship!
                puts "Orden despachada"
              else
                stop_scheduler = true
              end
            end # end lock iu
          end # end iteracion iu

          if stop_scheduler
            raise "Botamos aproposito para que no siga ejecutanto"
          end
        end # end if paid
      end  # end lock shipment
    end # end shipment
  end

	def despachar_ordenes  # hago esto por si ocupo mas de una funcion shipment
		despachar
	end

end