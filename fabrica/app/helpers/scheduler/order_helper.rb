module Scheduler::OrderHelper

	def marcar_vencidas
		Spree::Order.where("fechaEntrega <= ?", DateTime.now).where.not(state: "canceled").each do |order|
			order.canceled_by(Spree::User.first)  ## el primero se supone que es el admin
		end
	end

	def aceptar_ordenes
		##
		## Una orden tiene mas o menos 24 horas para ser acepta. Voy a analizar si
		## acepto fabricar dentro de las 16 horas pasadas (osea, que le queden 8 horas)
		## para caducar. Esto por que la fabricacion toma a veces 12 horas.
		## Fabrico hasta tres lotes maximos (mando uno a uno)
		##
		## A las ordenes caducan en menos de 8 horas le despacho solo si tengo para satisfacer
		## la mitad o mas de lo que le falta (siempre deberia ser a lo mas una orden que se encuentra asi)
		##
		## Cuando le quedan 1 hora o menos para que caduque una orden puede que le despache
		## eso depende de si los productos que me piden se me vencen dentro de 6 horas o si es
		## cubro toda su demanda
		##
		ordenes = []  # [orden, costo_un_lote, lotes, costo_total]
		ordenes_query = Spree::Order.where(state: "complete", channel: "ftp", payment_state: "paid").where("fechaEntrega >= ?", 16.hours.ago).each do |order|
			order.inventory_units.each do |iu|
				variant = iu.variant

				costo = variant.ingredients.sum(:lote_minimo)  ## llamamos costo a la cantidad de productos que hay que utilizar

				costo_lote = variant.lote_minimo
				lotes = BigDecimal((iu.quantity.to_f/variant.lote_minimo.to_f).to_s).ceil
				ordenes << [order, costo_lote, lotes, costo_lote * lotes]
			end
		end

		ordenes = ordenes.sort_by{ |i| i[1] }  ## primero ordeno por costo de un lote
		ordenes = ordenes.sort_by{ |i| i[3] }  ## despues ordeno por costo total
		# asi va a quedar mas importante costo total

		puts ordenes
		j = 0
		while j < (ordenes_query.count/3).floor
			j += 1
			puts j
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