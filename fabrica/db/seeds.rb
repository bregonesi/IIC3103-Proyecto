# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
require 'csv'

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
#####################################inicio CSV1######################
productos_csv_text = File.read(Rails.root.join('lib', 'seeds', 'productos.csv'))
#puts productos_csv_text

productos_csv = CSV.parse(productos_csv_text, :headers => true, :encoding => 'ISO-8859-1')
default_shipping_category = Spree::ShippingCategory.find_by!(name: "Default")
productos_csv.each do |product_attrs|
  Spree::Config[:currency] = "CLP"

  new_product = Spree::Product.where(name: product_attrs['Producto'], tax_category: product_attrs[:tax_category]).first_or_create! do |product|

    product.price = 100
    product.sku = product_attrs['SKU'.to_i]
    product.available_on = Time.zone.now
    product.shipping_category = default_shipping_category
  end

  sku = product_attrs['SKU'.to_i].to_s
  variante = Spree::Variant.find_by(sku: sku)
  costo_unitario = product_attrs['Costo']
  puts "Costo: " + costo_unitario
  variante.cost_price = costo_unitario.to_i
  variante.save!

  if new_product
    new_product.save
  end
end
#####################################fin CSV1######################

#####################################inicio CSV2######################
print "Cargando formulas.\n"
formulas_csv_text = File.read(Rails.root.join('lib', 'seeds', 'formulas.csv'))
#puts formulas_csv_text

formulas_csv = CSV.parse(formulas_csv_text, :headers => true, :encoding => 'ISO-8859-1')

formulas_csv.each do |formula_attrs|
  puts formula_attrs

  sku = formula_attrs['SKU'.to_i].to_s
  puts "sku_formula: " + sku

  variante = Spree::Variant.find_by(sku: sku)

  variante.lote_minimo = formula_attrs['Lote']
  variante.save!

  if formula_attrs['Manzana'].to_i > 0
    variante.recipe.build({variant_ingredient: Spree::Variant.find_by(sku: "20"), amount: formula_attrs['Manzana'].to_i}).save!
  end
  if formula_attrs['Naranja'].to_i > 0
    variante.recipe.build({variant_ingredient: Spree::Variant.find_by(sku: "30"), amount: formula_attrs['Naranja'].to_i}).save!
  end
  if formula_attrs['Frutilla'].to_i > 0
    variante.recipe.build({variant_ingredient: Spree::Variant.find_by(sku: "40"), amount: formula_attrs['Frutilla'].to_i}).save!
  end
  if formula_attrs['Frambuesa'].to_i > 0
    variante.recipe.build({variant_ingredient: Spree::Variant.find_by(sku: "50"), amount: formula_attrs['Frambuesa'].to_i}).save!
  end
  if formula_attrs['Durazno'].to_i > 0
    variante.recipe.build({variant_ingredient: Spree::Variant.find_by(sku: "60"), amount: formula_attrs['Durazno'].to_i}).save!
  end
  if formula_attrs['Arándano'].to_i > 0
    variante.recipe.build({variant_ingredient: Spree::Variant.find_by(sku: "70"), amount: formula_attrs['Arándano'].to_i}).save!
  end
end
################################fin CSV2

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

# Stocks iniciales productos #
print "Cargando stock iniciales de productos.\n"
Scheduler::ProductosHelper.cargar_nuevos

# Set hook #
print "Seteando hook.\n"
Scheduler::ConstantesHelper.set_hook

# Set cuenta banco api #
print "Seteando cuenta banco api.\n"
Scheduler::ConstantesHelper.api_cuenta_banco

# Descargamos nuevas ordenes
print "Descargando y agregando ordenes al por mayor.\n"
Scheduler::SftpHelper.agregar_nuevas_ordenes
