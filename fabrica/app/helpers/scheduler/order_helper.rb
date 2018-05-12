module Scheduler::OrderHelper

	def marcar_vencidas
		Spree::Order.where("fechaEntrega <= ?", DateTime.now).where.not(state: "canceled").each do |order|
			order.canceled_by(Spree::User.first)  ## el primero se supone que es el admin
		end
	end

	def cambiar_almacen
		# primero las que compramos por spree
		Spree::Order.where(channel: "spree", shipment_state: "backorder").each do |orden|  ## estas son las que se compran por ecomerce, hay que si o si atenderlas asap
			orden.shipments.each do |shipment|
				shipment.inventory_units.each do |iu|
					# hay que mover los items de almacen X a almacen despacho
					Spree::Shipment.find(shipment.id).transfer_to_location(
																							Spree::Variant.find(iu.variant.id),
																							iu.quantity.to_i,
																							Spree::StockLocation.where(proposito: "Despacho").first)
				end
			end
		end

	end

end