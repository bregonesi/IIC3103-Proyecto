class Spree::Gateway::Apipay < Spree::Gateway
  def provider_class
  	puts "Entro a provider class"
    Spree::Gateway::Apipay
  end

  def payment_source_class
  	puts "Entro a payment source class"
    Spree::Check
  end

  def method_type
  	puts "Entro a method type"
    'apipay'
  end

  def purchase(amount, transaction_details, options = {})
  	puts "Entro a purchase"
    ActiveMerchant::Billing::Response.new(false, 'success 1', {}, {})
  end

  def authorize(amount, transaction_details, options = {})
  	puts "Entro a authorize"
    ActiveMerchant::Billing::Response.new(false, 'success 2', {}, {})
  end

  def capture(*)
  	puts "Entro a capture"
    simulated_successful_billing_response
  end

  def cancel(*)
  	puts "Entro a cancel"
    simulated_successful_billing_response
  end

  def void(*)
  	puts "Entro a void"
    simulated_successful_billing_response
  end

  def source_required?
  	puts "Entro a source_required"
    false
  end

  private
	  def simulated_successful_billing_response
	    ActiveMerchant::Billing::Response.new(false, '', {}, {})
	  end
end
