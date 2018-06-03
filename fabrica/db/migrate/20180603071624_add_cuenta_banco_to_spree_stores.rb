class AddCuentaBancoToSpreeStores < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_stores, :cuenta_banco, :string
  end
end
