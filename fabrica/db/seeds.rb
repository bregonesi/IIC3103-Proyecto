# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Spree::Core::Engine.load_seed if defined?(Spree::Core)
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)

Spree::StockLocation.destroy_all

# Products #
Spree::Sample.load_sample("shipping_categories")

products = [
  {
    name: "Manzana",
    description: "Esta es una manzana",
    price: 100
  },
  {
    name: "Jugo Manzana",
    description: "Esta es un jugo manzana",
    price: 1000
  },
  {
    name: "Jugo Manzana-Naranja",
    description: "Esta es un jugo manzana naranja",
    price: 1200
  }
]

default_shipping_category = Spree::ShippingCategory.find_by!(name: "Default")

products.each do |product_attrs|
	Spree::Config[:currency] = "CLP"

  new_product = Spree::Product.where(name: product_attrs[:name],
                                     tax_category: product_attrs[:tax_category]).first_or_create! do |product|
    product.price = product_attrs[:price]
    #product.description = FFaker::Lorem.paragraph
    product.description = product_attrs[:description]
    product.available_on = Time.zone.now
    product.shipping_category = default_shipping_category
  end

  if new_product
    new_product.save
  end
end

# Object types #
option_types_attributes = [
  {
    name: "category",
    presentation: "Categoria",
    position: 1
  }
]

option_types_attributes.each do |attrs|
  Spree::OptionType.where(attrs).first_or_create!
end

# Object value #
category = Spree::OptionType.find_by!(presentation: "Categoria")

option_values_attributes = [
  {
    name: "Fruit",
    presentation: "Fruta",
    position: 1,
    option_type: category
  },
  {
    name: "Juice",
    presentation: "Jugo",
    position: 2,
    option_type: category
  }
]

option_values_attributes.each do |attrs|
  Spree::OptionValue.where(attrs).first_or_create!
end

# Skus #
manzana = Spree::Product.find_by!(name: "Manzana")
jugo_manzana = Spree::Product.find_by!(name: "Jugo Manzana")
jugo_manana_naranja = Spree::Product.find_by!(name: "Jugo Manzana-Naranja")

masters = {
  manzana => {
    sku: "20",
    cost_price: 10,
  },
  jugo_manzana => {
    sku: "200000000",
    cost_price: 20
  },
  jugo_manana_naranja => {
    sku: "230000000",
    cost_price: 30
  }
}

masters.each do |product, variant_attrs|
  product.master.update_attributes!(variant_attrs)
end

# Stocks location #
url = ENV['api_url'] + "bodega/almacenes"

base = 'GET'
key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

r = RestClient::Request.execute(method: :get, url: url,
	headers: {'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})
i = 0
JSON.parse(r).each do |almacen|
	i += 1
  new_almacen = Spree::StockLocation.where(name: 'Almacen ' + i.to_s).first_or_create! do |a_new|
    a_new.admin_name = almacen['_id']
  end

  if new_almacen
    new_almacen.save
  end
end