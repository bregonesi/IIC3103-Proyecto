class AddPrecioMaximoToOcRequest < ActiveRecord::Migration[5.1]
  def change
    add_column :oc_requests, :precio_maximo, :integer, default: 0
  end
end
