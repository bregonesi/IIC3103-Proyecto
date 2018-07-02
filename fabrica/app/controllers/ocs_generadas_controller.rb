class OcsGeneradasController < ApplicationController
  before_action :set_ocs_generada, only: [:show, :edit, :update, :destroy]

  # GET /ocs_generadas
  # GET /ocs_generadas.json
  def index
    @ocs_generadas = OcsGenerada.order(id: :desc).page(params[:page]).per(300)
  end

  # GET /ocs_generadas/1
  # GET /ocs_generadas/1.json
  def show
  end

  # GET /ocs_generadas/new
  def new
    @ocs_generada = OcsGenerada.new
  end

  # GET /ocs_generadas/1/edit
  def edit
  end

  # POST /ocs_generadas
  # POST /ocs_generadas.json
  def create
    @ocs_generada = OcsGenerada.new(ocs_generada_params)

    respond_to do |format|
      if @ocs_generada.save
        format.html { redirect_to @ocs_generada, notice: 'Ocs generada was successfully created.' }
        format.json { render :show, status: :created, location: @ocs_generada }
      else
        format.html { render :new }
        format.json { render json: @ocs_generada.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /ocs_generadas/1
  # PATCH/PUT /ocs_generadas/1.json
  def update
    respond_to do |format|
      if @ocs_generada.update(ocs_generada_params)
        format.html { redirect_to @ocs_generada, notice: 'Ocs generada was successfully updated.' }
        format.json { render :show, status: :ok, location: @ocs_generada }
      else
        format.html { render :edit }
        format.json { render json: @ocs_generada.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /ocs_generadas/1
  # DELETE /ocs_generadas/1.json
  def destroy
    @ocs_generada.destroy
    respond_to do |format|
      format.html { redirect_to ocs_generadas_url, notice: 'Ocs generada was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_ocs_generada
      @ocs_generada = OcsGenerada.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def ocs_generada_params
      params.require(:ocs_generada).permit(:oc_request_id, :oc_id, :grupo, :cliente, :proveedor, :sku, :fechaEntrega, :cantidad, :cantidadDespachada, :precioUnitario, :canal, :notas, :urlNotificacion, :estado)
    end
end
