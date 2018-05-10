Spree::Variant.class_eval do
  has_many :recipes, foreign_key: 'sku', primary_key:'sku'
  has_many :ingredient_recipes, class_name: 'Recipe',
  foreign_key: 'ingredient_variant_sku', primary_key:'sku'
end
