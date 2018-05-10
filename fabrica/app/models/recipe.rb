class Recipe < ApplicationRecord
  belongs_to :spree_variant, class_name: 'Spree::Variant', foreign_key: 'sku', primary_key:'sku'
  belongs_to :ingredient, class_name: 'Spree::Variant', foreign_key: 'ingredient_variant_sku', primary_key: 'sku'
end
