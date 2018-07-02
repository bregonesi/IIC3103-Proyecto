class OrdenCompra < ApplicationRecord

	def self.aceptadas
		self.where(estado: "aceptada")
	end

	def self.finalizadas
		self.where(estado: "finalizada")
	end

	def self.aceptadas_de_cliente(cliente)
		OrdenCompra.aceptadas.where(cliente: cliente) + OrdenCompra.finalizadas.where(cliente: cliente)
	end

	def self.cantidad_maxima_aceptar_de_cliente(cliente)
		(OcsGenerada.where(estado: "aceptada", proveedor: cliente).count + OcsGenerada.where(estado: "finalizada", proveedor: cliente).count + 1) * 2
	end

	def acepto?
		OrdenCompra.cantidad_maxima_aceptar_de_cliente(self.cliente) > OrdenCompra.aceptadas_de_cliente(self.cliente).count
	end
end
