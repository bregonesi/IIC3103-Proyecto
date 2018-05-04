class HookController < ApplicationController
  include ApplicationHelper

  skip_before_action :verify_authenticity_token

  def materias_primas
    productos = Spree::Product.all
    sku_producto = params[:sku]
    producto = Spree::Variant.find_by(sku: sku_producto)
    if producto
      stock = producto.total_on_hand
      #if stock < 10
        render json: stock, :status => 200  ## voy a dejar que siempre retorne 200 para aceptar todo por mientras
        HookRequest.create!(sku: sku_producto, cantidad: params[:cantidad], disponible: params[:disponible],
          ip: ip2long(request.remote_ip), aceptado: true, razon: "Estoy aceptando todo")
      #else
      #  render json: @stock, :status => 401
      #  HookRequests.create!(sku: sku_producto, cantidad: params[:cantidad], disponible: params[:disponible],
      #    ip: ip2long(request.remote_ip), aceptado: false, razon: "Fue rechazado por que stock es X cantidad")
      #end
    else
      render json: [{:error => "Producto sku " + sku_producto + " no existe."}], :status => 400
      HookRequest.create!(sku: sku_producto, cantidad: params[:cantidad], disponible: params[:disponible],
          ip: ip2long(request.remote_ip), aceptado: true, razon: "Rechazado por que sku no existe.")
    end
  end

  def list_requests
    render json: HookRequest.all
  end

  private
	  def hook_params
	    params.require(:hook).permit(:sku, :cantidad, :disponible)
	  end
end
