module Spree
  CheckoutController.class_eval do
    skip_before_action :verify_authenticity_token, :ensure_valid_state
    before_action :api_gateway_supper, :only => [:edit]
    before_action :api_gateway_hook, :only => [:update]

    def api_gateway_supper
      if params[:state] == "payment"
        if cookies[:api_gateway_respuesta] == "1"
          cookies.delete :api_gateway_offsite_payment
          cookies.delete :api_gateway_respuesta
          @order.next
          @current_order = nil
          flash.notice = Spree.t(:order_processed_successfully)
          flash['order_completed'] = true
          redirect_to completion_route
        elsif cookies[:api_gateway_respuesta] == "0"
          flash[:error] = "Metodo de pago falló"
          cookies.delete :api_gateway_offsite_payment
          cookies.delete :api_gateway_respuesta
        end
      end
    end

    def api_gateway_hook
      cookies.delete(:api_gateway_offsite_payment) unless (params[:state] == "payment")
      cookies.delete(:api_gateway_respuesta) unless (params[:state] == "payment")
      return unless (params[:state] == "payment")
      return unless params[:order][:payments_attributes]

      payment_method_id = PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])
      cookies.delete(:api_gateway_offsite_payment) unless payment_method_id.kind_of?(Gateway::Apipay)

      if payment_method_id.id == 2
        load_order_with_lock
        @order.payments.where(amount: @order.total, payment_method_id: payment_method_id.id).first_or_create!
        cookies[:api_gateway_offsite_payment] = { value: true, expires: 1.hour.from_now }
        redirect_to(checkout_state_path("payment")) && return
      end
    end

    def api_gateway_url
      # Creo boleta #
      boleta = Invoice.create!(originator_type: @order.class.name.to_s, originator: @order.id.to_i) do |f|
        
        boleta_request = HTTParty.put(ENV['api_sii_url'] + "boleta",
                                      body: {proveedor: $info_grupos[4][:id].to_s,
                                             cliente: @order.shipments.first.address.firstname.to_s,
                                             total: @order.total.to_i}.to_json,
                                      headers: { 'Content-type': 'application/json'})

        puts boleta_request

        if boleta_request.code == 200
          body = JSON.parse(boleta_request.body)
          f._id = body["_id"]
          f.cliente = body["cliente"]
          f.proveedor = body["proveedor"]
          f.oc = body["oc"]["_id"]
          f.bruto = body["bruto"]
          f.iva = body["iva"]
          f.total = body["total"]
          f.estado = body["estado"]
          f.created_at = body["created_at"]
          f.updated_at = body["updated_at"]
        else
          puts "Error en crear boleta"
          puts boleta_request
        end
      end

      url = ENV['boleta_url'] + "pagoenlinea?callbackUrl=" + URI.encode(ENV['mi_url'] + url_for(main_app.api_gateway_success_order_checkout_path(@order))) + "&cancelUrl=" + URI.encode(ENV['mi_url'] + url_for(main_app.api_gateway_fail_order_checkout_path(@order))) + "&boletaId=" + boleta._id.to_s
      print url
      redirect_to url
    end

    def api_gateway_success
      boleta = Invoice.where(originator_type: @order.class.name.to_s, originator: @order.id.to_i).last
      if !boleta.nil?
        boleta_request = HTTParty.get(ENV['api_sii_url'] + boleta._id.to_s, body: { }.to_json, headers: { 'Content-type': 'application/json'})

        if boleta_request.code == 200
          body = JSON.parse(boleta_request.body)[0]
          boleta.estado = body["estado"]
          boleta.save!
        else
          puts "Error en get boleta"
          puts boleta_request
        end
      end
      @order.payments.last.update_columns(state: 'checkout')
      @order.confirmation_delivered = true

      cookies[:api_gateway_offsite_payment] = { value: true, expires: 1.hour.from_now }
      cookies[:api_gateway_respuesta] = { value: 1, expires: 1.hour.from_now }
      render "_exit_api_gateway"
    end

    def api_gateway_fail
      boleta = Invoice.where(originator_type: @order.class.name.to_s, originator: @order.id.to_i).last
      if !boleta.nil?
        boleta_request = HTTParty.get(ENV['api_sii_url'] + boleta._id.to_s, body: { }.to_json, headers: { 'Content-type': 'application/json'})

        if boleta_request.code == 200
          body = JSON.parse(boleta_request.body)[0]
          boleta.estado = body["estado"]
          boleta.rechazo = body["rechazo"] || ""
          boleta.save!
        else
          puts "Error en get boleta"
          puts boleta_request
        end
      end

      cookies[:api_gateway_offsite_payment] = { value: true, expires: 1.hour.from_now }
      cookies[:api_gateway_respuesta] = { value: 0, expires: 1.hour.from_now }
      render "_exit_api_gateway"
    end

    private
      def payment_method
        @payment_method ||= PaymentMethod.find(@order.payments.last.payment_method)
      end

  end
end