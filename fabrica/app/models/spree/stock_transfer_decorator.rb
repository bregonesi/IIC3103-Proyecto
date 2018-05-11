Spree::StockTransfer.class_eval do
  alias_method :old_transfer, :transfer

	def transfer(*args)
    if args[1].proposito == "Pulmon"
      raise "No se puede transferir a Pulmon."
    end

    old_transfer(*args)
  end
end