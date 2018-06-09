class OrdenComprasController < ApplicationController
  before_action :set_orden_compra, only: [:show, :edit, :update, :destroy]

  # GET /orden_compras
  # GET /orden_compras.json
  def index
    @orden_compras = OrdenCompra.all.order(id: :desc)
  end

  # GET /orden_compras/1
  # GET /orden_compras/1.json
  def show
  end

  # GET /orden_compras/new
  def new
    @orden_compra = OrdenCompra.new
  end

  # GET /orden_compras/1/edit
  def edit
  end

  # POST /orden_compras
  # POST /orden_compras.json
  def create
    @orden_compra = OrdenCompra.new(orden_compra_params)

    respond_to do |format|
      if @orden_compra.save
        format.html { redirect_to @orden_compra, notice: 'Orden compra was successfully created.' }
        format.json { render :show, status: :created, location: @orden_compra }
      else
        format.html { render :new }
        format.json { render json: @orden_compra.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orden_compras/1
  # PATCH/PUT /orden_compras/1.json
  def update
    respond_to do |format|
      if @orden_compra.update(orden_compra_params)
        format.html { redirect_to @orden_compra, notice: 'Orden compra was successfully updated.' }
        format.json { render :show, status: :ok, location: @orden_compra }
      else
        format.html { render :edit }
        format.json { render json: @orden_compra.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orden_compras/1
  # DELETE /orden_compras/1.json
  def destroy
    @orden_compra.destroy
    respond_to do |format|
      format.html { redirect_to orden_compras_url, notice: 'Orden compra was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_orden_compra
      @orden_compra = OrdenCompra.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def orden_compra_params
      params.require(:orden_compra).permit(:_id, :cliente, :proveedor, :sku, :fechaEntrega, :cantidad, :cantidadDespachada, :precioUnitario, :canal, :estado, :notas, :rechazo, :anulacion, :urlNotificacion, :created_at, :updated_at)
    end
end
