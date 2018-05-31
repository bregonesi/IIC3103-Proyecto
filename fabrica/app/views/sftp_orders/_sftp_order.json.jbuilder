json.extract! sftp_order, :id, :oc, :cliente, :proveedor, :sku, :fechaEntrega, :cantidad, :myCantidadDespachada, :serverCantidadDespachada, :precioUnitario, :canal, :notas, :rechazo, :anulacion, :urlNotificacion, :myEstado, :serverEstado, :created_at, :updated_at
json.url sftp_order_url(sftp_order, format: :json)
