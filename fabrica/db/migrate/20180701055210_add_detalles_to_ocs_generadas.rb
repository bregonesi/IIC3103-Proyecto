class AddDetallesToOcsGeneradas < ActiveRecord::Migration[5.1]
  def change
    add_column :ocs_generadas, :rechazo, :string
    add_column :ocs_generadas, :anulacion, :string
  end
end
