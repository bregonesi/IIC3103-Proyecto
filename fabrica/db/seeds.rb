# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

include SchedulerHelper

Spree::Core::Engine.load_seed if defined?(Spree::Core)
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)

Spree::StockLocation.destroy_all
Spree::PaymentMethod.destroy_all

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

# Customer address
print "Cargando customer address.\n"
Spree::Address.create!(firstname: "Distribuidor",
                       lastname: "PUC",
                       address1: 'Av. Vicuña Mackenna 4860',
                       city: 'Santiago',
                       state: Spree::Country.find_by(iso: 'CL').states.find_by(abbr: 'RM'),
                       zipcode: '7820436',
                       country: Spree::Country.find_by(iso: 'CL'),
                       phone: FFaker::PhoneNumber.phone_number
)

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
Spree::Sample.load_sample("shipping_categories")
require 'csv'

csv_text = File.read(Rails.root.join('lib', 'seeds', 'Grupos.csv'))
puts csv_text

csv = CSV.parse(csv_text, :headers => true, :encoding => 'ISO-8859-1')
default_shipping_category = Spree::ShippingCategory.find_by!(name: "Default")
csv.each do |product_attrs|
  Spree::Config[:currency] = "CLP"

  new_product = Spree::Product.where(name: product_attrs['Producto'],
    tax_category: product_attrs[:tax_category]).first_or_create! do |product|

    product.price = 1000
    product.sku = product_attrs['SKU'.to_i]
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

# Stocks location #
print "Cargando stock locations.\n"
Scheduler::AlmacenesHelper.nuevos_almacenes
nombre = Spree::StockLocation.count > 0 ? Spree::StockLocation.last.name.split(" ")[1].to_i + 1 : 1
new_almacen = Spree::StockLocation.where(name: 'Almacen ' + nombre.to_s,
                                         address1: 'Av. Vicuña Mackenna 4860',
                                         city: 'Santiago',
                                         zipcode: '7820436',
                                         country: Spree::Country.find_by(iso: 'CL'),
                                         state: Spree::Country.find_by(iso: 'CL').states.find_by(abbr: 'RM')
                                        ).first_or_create! do |a_new|
  a_new.admin_name = "Backorderable"
  a_new.backorderable_default = true
  a_new.proposito = "Backorderable"
  a_new.capacidad_maxima = 99999999
end
if new_almacen
  new_almacen.save!
end

# Stocks iniciales productos #
print "Cargando stock iniciales de productos.\n"
Scheduler::ProductosHelper.cargar_nuevos

# Set hook #
print "Seteando hook.\n"

url = ENV['api_url'] + "bodega/hook"
hook_url = 'http://integra4.ing.puc.cl/hook'

base = 'GET'
key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
r = HTTParty.get(url, headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook

if r.code == 200
  if JSON.parse(r.body)["url"] != hook_url
    print "Cambio hook.\n"

    base = 'DELETE'
    key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
    HTTParty.delete(url,
                    body: {}.to_json,  # empty json
                    headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook

    base = 'PUT' + hook_url
    key = Base64.encode64(OpenSSL::HMAC.digest('sha1', ENV['api_psswd'], base))
    HTTParty.put(url,
                 body: {url: hook_url}.to_json,
                 headers: { 'Content-type': 'application/json', 'Authorization': 'INTEGRACION grupo4:' + key})  # primero eliminamos hook
  else
    print "Hook no cambio. No seteamos nuevo hook.\n"
  end
else
  print "Error. Response code not 200.\n"
end

# Descargamos nuevas ordenes
print "Descargando y agregando ordenes al por mayor.\n"
Scheduler::SftpHelper.agregar_nuevas_ordenes
