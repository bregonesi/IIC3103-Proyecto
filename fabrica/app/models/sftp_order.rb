class SftpOrder < ApplicationRecord

  def can_accept?
    variant = Spree::Variant.find_by(sku: self.sku)
    if variant.total_on_hand >= self.qty
      return true #se acepta
    end
    return false
  end





end

# si tenemos la cantidad del producto solicitado por el pedido, retorna true
