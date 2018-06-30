class CreateInvoices < ActiveRecord::Migration[5.1]
  def change
    create_table :invoices do |t|
      t.string :_id
      t.integer :bruto
      t.integer :iva
      t.integer :total
      t.string :proveedor
      t.string :cliente
      t.string :oc
      t.string :estado
      t.string :rechazo
      t.string :anulacion
      t.string :originator_type
      t.integer :originator

      t.timestamps
    end
  end
end
