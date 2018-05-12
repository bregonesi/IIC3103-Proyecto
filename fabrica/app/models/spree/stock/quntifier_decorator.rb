Spree::Stock::Quantifier.class_eval do
  def total_on_hand
    if variant.should_track_inventory?
      stock_items.where(backorderable: false).sum(:count_on_hand)
    else
      Float::INFINITY
    end
  end
end