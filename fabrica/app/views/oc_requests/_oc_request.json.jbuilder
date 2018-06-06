json.extract! oc_request, :id, :sftp_order_id, :sku, :cantidad, :por_responder, :aceptado, :despachado, :created_at, :updated_at
json.url oc_request_url(oc_request, format: :json)
