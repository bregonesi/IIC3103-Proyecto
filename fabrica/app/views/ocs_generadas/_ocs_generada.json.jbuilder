json.extract! ocs_generada, :id, :oc_request_id, :oc_id, :grupo, :cliente, :proveedor, :sku, :fechaEntrega, :cantidad, :precioUnitario, :canal, :notas, :urlNotificacion, :created_at, :updated_at
json.url ocs_generada_url(ocs_generada, format: :json)
