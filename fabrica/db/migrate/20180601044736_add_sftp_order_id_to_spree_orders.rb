class AddSftpOrderIdToSpreeOrders < ActiveRecord::Migration[5.1]
  def change
    add_reference :spree_orders, :sftp_order, foreign_key: true
  end
end
