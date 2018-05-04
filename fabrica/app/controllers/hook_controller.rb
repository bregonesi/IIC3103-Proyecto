class HookController < ApplicationController
  skip_before_action :verify_authenticity_token
  def materias_primas
    productos = Spree::Product.all
    @sku_producto = params[:sku]
    @producto = Spree::Variant.find_by(sku: @sku_producto)
    if @producto
      @stock = @producto.total_on_hand
      #if @stock < 10
        render json: @stock, :status => 200  ## voy a dejar que siempre retorne 200 para aceptar todo por mientras
      #else
      #  render json: @stock, :status => 401
      #end
    else
      render json: @producto, :status => 400
    end
  end

  private
	  def hook_params
	    params.require(:hook).permit(:sku, :cantidad, :disponible)
	  end
end
