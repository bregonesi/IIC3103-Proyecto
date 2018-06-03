class CreateTransferencia < ActiveRecord::Migration[5.1]
  def change
    create_table :transferencia do |t|
      t.string :origen
      t.string :string
      t.string :destino
      t.integer :monto
      t.string :idtransferencia
      t.string :string
      t.string :originator_type
      t.string :string
      t.string :originator_id
      t.string :integer

      t.timestamps
    end
  end
end
