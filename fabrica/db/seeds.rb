# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Spree::Core::Engine.load_seed if defined?(Spree::Core)
#Spree::Sample.load_sample("country")
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)

Spree::StockLocation.destroy_all

# Zones #
print "Cargando zones.\n"

zone = Spree::Zone.where(name: "Chile").create! do |z_new|
  z_new.description = "Solo Chile. Uso de IVA"
  z_new.default_tax = true
  z_new.kind = "country"

  z_new.zone_members.build(zoneable: Spree::Country.find_by!(iso: "CL")).save!
end

# Tax's #
print "Cargando taxs.\n"

tax_category = Spree::TaxCategory.where(name: 'IVA Chile').first_or_create!
Spree::TaxRate.where(
  name: "IVA Chile",
  zone: zone,
  amount: 0.19,
  tax_category: tax_category,
  included_in_price: true,
  show_rate_in_label: true).first_or_create! do |tax_rate|
  tax_rate.calculator = Spree::Calculator::DefaultTax.create!
end

# Shipping categories y methods #
print "Cargando shipping categories y methods.\n"

shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'Default')

shipping_methods = [
  {
    name: "Despacho por API",
    zones: [zone],
    display_on: 'both',
    shipping_categories: [shipping_category]
  }
]

shipping_methods.each do |attributes|
  Spree::ShippingMethod.where(name: attributes[:name]).first_or_create! do |shipping_method|
    shipping_method.calculator = Spree::Calculator::Shipping::FlatRate.create!
    shipping_method.calculator.preferences = {
      amount: 0,
      currency: "CLP"
    }
    shipping_method.calculator.save!

    shipping_method.zones = attributes[:zones]
    shipping_method.display_on = attributes[:display_on]
    shipping_method.shipping_categories = attributes[:shipping_categories]
  end
end

# Payment methods #
print "Cargando payment methods.\n"

Spree::PaymentMethod::Check.where(
  name: "Gratis",
  description: "Pago por api.",
  active: true
).first_or_create!

# Products #
print "Cargando productos.\n"

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
print "Cargando object types.\n"

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
print "Cargando object values.\n"

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
print "Cargando skus.\n"

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
print "Cargando stock locations.\n"

url = ENV['api_url'] + "bodega/almacenes"

base = 'GET'
key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

r = RestClient::Request.execute(method: :get, url: url,
	headers: {'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})

i = 0

JSON.parse(r).each do |almacen|
  print "Almacen " + almacen['_id'].to_s + " detectado.\n"

	i += 1
  new_almacen = Spree::StockLocation.where(name: 'Almacen ' + i.to_s,
                                           address1: 'Av. Vicuña Mackenna 4860',
                                           city: 'Santiago',
                                           zipcode: '7820436',
                                           country: Spree::Country.find_by(iso: 'CL'),
                                           state: Spree::Country.find_by(iso: 'CL').states.find_by(abbr: 'RM')
                                          ).first_or_create! do |a_new|
    a_new.admin_name = almacen['_id']
  end

  if new_almacen
    new_almacen.save
  end
end

# Stocks iniciales productos #
print "Cargando stock iniciales de productos.\n"

url = ENV['api_url'] + "bodega/skusWithStock"

Spree::StockLocation.all.each do |stock_location|
  base = 'GET' + stock_location.admin_name
  key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))

  r = RestClient::Request.execute(method: :get, url: url,
    headers: {
      params: {almacenId: stock_location.admin_name.to_s},
      'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key}
      )

  JSON.parse(r).each do |prod_api|
    variant = Spree::Variant.find_by(sku: prod_api['_id'].to_s)
    if variant
      print "Variant sku: " + prod_api['_id'] + " encontrada.\n"

      stock_item = Spree::StockItem.find_by(stock_location: stock_location, variant: variant)
      if stock_item
        stock_item.count_on_hand = prod_api['total'].to_i
        print "Cargando stock para item sku: " + prod_api['_id'] + ", stock: " + prod_api['total'].to_s + ".\n"
      end

      if stock_item
        stock_item.save
      end
    else
      print "Variant sku: " + prod_api['_id'] + " no encontrada.\n"
    end
  end
end