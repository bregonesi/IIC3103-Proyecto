class CreateSftpOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :sftp_orders do |t|
      t.string :orderId
      t.string :sku
      t.integer :qty

      t.timestamps
    end
  end
end
