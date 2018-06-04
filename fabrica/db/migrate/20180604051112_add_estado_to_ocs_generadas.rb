class AddEstadoToOcsGeneradas < ActiveRecord::Migration[5.1]
  def change
    add_column :ocs_generadas, :estado, :string
  end
end
