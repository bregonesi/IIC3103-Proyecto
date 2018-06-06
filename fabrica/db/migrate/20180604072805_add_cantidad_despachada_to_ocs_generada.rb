class AddCantidadDespachadaToOcsGenerada < ActiveRecord::Migration[5.1]
  def change
    add_column :ocs_generadas, :cantidadDespachada, :integer
  end
end
