json.extract! invoice, :id, :_id, :bruto, :iva, :total, :proveedor, :cliente, :oc, :estado, :rechazo, :anulacion, :originator_type, :originator, :created_at, :updated_at
json.url invoice_url(invoice, format: :json)
