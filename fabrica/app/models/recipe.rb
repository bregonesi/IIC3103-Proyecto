class Recipe < ApplicationRecord
  belongs_to :variant_product, class_name: 'Spree::Variant'
  belongs_to :variant_ingredient, class_name: 'Spree::Variant'

  validates :variant_product, presence: true
  validates :variant_ingredient, presence: true
end
