class OrdenCompra < ApplicationRecord

	def self.aceptadas
		self.where(estado: "aceptada")
	end

	def self.finalizadas
		self.where(estado: "finalizada")
	end

	def self.aceptadas_de_cliente(cliente)
		self.aceptadas.where(cliente: cliente) + self.finalizadas.where(cliente: cliente)
	end

	def acepto?(critico=0.7)
		OrdenCompra.aceptadas.count == 0 || (OrdenCompra.aceptadas_de_cliente(self.cliente).count.to_f / OrdenCompra.aceptadas.count.to_f) <= critico
	end
end
