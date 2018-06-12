class SftpOrdersController < ApplicationController
  before_action :set_sftp_order, only: [:show, :edit, :update, :destroy]

  # GET /sftp_orders
  # GET /sftp_orders.json
  def index
    @sftp_orders = SftpOrder.order(id: :desc)
  end

  # GET /sftp_orders/1
  # GET /sftp_orders/1.json
  def show
  end

  # GET /sftp_orders/1/edit
  def edit
  end

  # PATCH/PUT /sftp_orders/1
  # PATCH/PUT /sftp_orders/1.json
  def update
    respond_to do |format|
      if @sftp_order.update(sftp_order_params)
        format.html { redirect_to @sftp_order, notice: 'Sftp order was successfully updated.' }
        format.json { render :show, status: :ok, location: @sftp_order }
      else
        format.html { render :edit }
        format.json { render json: @sftp_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sftp_orders/1
  # DELETE /sftp_orders/1.json
  def destroy
    @sftp_order.destroy
    respond_to do |format|
      format.html { redirect_to sftp_orders_url, notice: 'Sftp order was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_sftp_order
      @sftp_order = SftpOrder.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def sftp_order_params
      params.require(:sftp_order).permit(:oc, :cliente, :proveedor, :sku, :fechaEntrega, :cantidad, :myCantidadDespachada, :serverCantidadDespachada, :precioUnitario, :canal, :notas, :rechazo, :anulacion, :urlNotificacion, :myEstado, :serverEstado)
    end
end
