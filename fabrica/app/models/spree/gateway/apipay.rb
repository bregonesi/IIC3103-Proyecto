class Spree::Gateway::Apipay < Spree::PaymentMethod::Check
  def provider_class
    Spree::Gateway::Apipay
  end

  def payment_source_class
    Spree::Check
  end

  def method_type
    'apipay'
  end

end
