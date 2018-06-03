json.extract! orden_compra, :id, :_id, :cliente, :proveedor, :sku, :fechaEntrega, :cantidad, :cantidadDespachada, :precioUnitario, :canal, :estado, :notas, :rechazo, :anulacion, :urlNotificacion, :created_at, :updated_at, :created_at, :updated_at
json.url orden_compra_url(orden_compra, format: :json)
