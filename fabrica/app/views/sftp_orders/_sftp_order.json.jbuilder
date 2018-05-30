json.extract! sftp_order, :id, :oc, :sku, :quantity, :cliente, :proveedor, :fechaEntrega, :canal, :urlNotificacion, :myEstado, :serverEstado, :created_at, :updated_at
json.url sftp_order_url(sftp_order, format: :json)
