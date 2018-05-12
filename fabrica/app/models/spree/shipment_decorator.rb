Spree::Shipment.class_eval do
  def transfer_to_location(variant, quantity, stock_location)  ## re escribimos por que tiene un error
    raise ArgumentError if quantity <= 0

    transaction do
      new_shipment = order.shipments.create!(stock_location: stock_location, address: order.ship_address)  ## originalmente no agrega address

      order.contents.remove(variant, quantity, shipment: self)
      order.contents.add(variant, quantity, shipment: new_shipment)
      order.create_tax_charge!
      order.update_with_updater!

      refresh_rates
      save! if persisted?
      new_shipment.save!
    end
  end
end
