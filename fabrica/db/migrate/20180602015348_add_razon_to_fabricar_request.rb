class AddRazonToFabricarRequest < ActiveRecord::Migration[5.1]
  def change
    add_column :fabricar_requests, :razon, :text
  end
end
