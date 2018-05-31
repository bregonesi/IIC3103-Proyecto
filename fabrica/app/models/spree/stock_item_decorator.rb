Spree::StockItem.class_eval do
  has_many :productos_api

  #scope :with_active_stock_location, -> { joins(:stock_location) }  ## forzamos a desactivar esto
end