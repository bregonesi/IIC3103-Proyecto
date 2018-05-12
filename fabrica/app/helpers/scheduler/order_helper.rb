module Scheduler::OrderHelper

	def marcar_vencidas
		Spree::Order.where("fechaEntrega <= ?", DateTime.now).where.not(state: "canceled").each do |order|
			order.canceled_by(Spree::User.first)  ## el primero se supone que es el admin
		end
	end

	def cambiar_items_a_despacho(variant, cantidad)  ## siempre vamos a mover para mantener con un stock
		despacho = Spree::StockLocation.where(proposito: "Despacho").first
		stock_item = despacho.stock_items.find_by(variant: variant)

    q = cantidad
    while q != 0
			productos_ordenados = ProductosApi.no_vencidos.order(:vencimiento)
			a_mover = productos_ordenados.where(stock_item: stock_item.variant.stock_items.where(backorderable: false)).where.not(stock_item: stock_item).group(:vencimiento)  ## quiero limit pero me tira error, asi que lo haremos a la mala

      if a_mover.empty?
      	break
      end

			a_mover_prods = a_mover.each

			prod = a_mover_prods.next

			a_mover_prods_count = a_mover.count[prod.vencimiento]

      variants = Hash.new(0)
      variants[prod.stock_item.variant] = [a_mover_prods_count, q].min

      stock_transfer = Spree::StockTransfer.create(reference: "Para poder despachar orden")
      stock_transfer.transfer(prod.stock_item.stock_location,
                              despacho,
                              variants)
      Scheduler::ProductosHelper.hacer_movimientos  ## hacemos los movs

      q -= [a_mover_prods_count, q].min
    end
	end

	def cambiar_almacen
		# primero las que compramos por spree
		Spree::Order.where(channel: "spree", shipment_state: "backorder").each do |orden|  ## estas son las que se compran por ecomerce, hay que si o si atenderlas asap
			orden.shipments.each do |shipment|
				shipment.with_lock do
					shipment.inventory_units.each do |iu|
						iu.with_lock do
							# cambiamos los prod al almacen de despacho
							cambiar_items_a_despacho(Spree::Variant.find(iu.variant.id), iu.quantity.to_i)

							# cambiamos el shipment de backorder a almacen de despacho
							Spree::Shipment.find(shipment.id).transfer_to_location(
																									Spree::Variant.find(iu.variant.id),
																									iu.quantity.to_i,
																									Spree::StockLocation.where(proposito: "Despacho").first)
						end
					end
				end
			end
		end

	end

end