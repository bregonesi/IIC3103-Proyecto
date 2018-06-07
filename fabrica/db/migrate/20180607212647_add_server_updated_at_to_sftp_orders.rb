class AddServerUpdatedAtToSftpOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :sftp_orders, :server_updated_at, :datetime
  end
end
