class OcRequestsController < ApplicationController
  before_action :set_oc_request, only: [:show, :edit, :update, :destroy]

  # GET /oc_requests
  # GET /oc_requests.json
  def index
    @oc_requests = OcRequest.all.order(id: :desc).page(params[:page]).per(300)
  end

  # GET /oc_requests/1
  # GET /oc_requests/1.json
  def show
  end

  # GET /oc_requests/new
  def new
    @oc_request = OcRequest.new
  end

  # GET /oc_requests/1/edit
  def edit
  end

  # POST /oc_requests
  # POST /oc_requests.json
  def create
    @oc_request = OcRequest.new(oc_request_params)

    respond_to do |format|
      if @oc_request.save
        format.html { redirect_to @oc_request, notice: 'Oc request was successfully created.' }
        format.json { render :show, status: :created, location: @oc_request }
      else
        format.html { render :new }
        format.json { render json: @oc_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /oc_requests/1
  # PATCH/PUT /oc_requests/1.json
  def update
    respond_to do |format|
      if @oc_request.update(oc_request_params)
        format.html { redirect_to @oc_request, notice: 'Oc request was successfully updated.' }
        format.json { render :show, status: :ok, location: @oc_request }
      else
        format.html { render :edit }
        format.json { render json: @oc_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /oc_requests/1
  # DELETE /oc_requests/1.json
  def destroy
    @oc_request.destroy
    respond_to do |format|
      format.html { redirect_to oc_requests_url, notice: 'Oc request was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_oc_request
      @oc_request = OcRequest.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def oc_request_params
      params.require(:oc_request).permit(:sftp_order_id, :sku, :cantidad, :precio_maximo, :por_responder, :aceptado, :despachado, :cantidad_pedida)
    end
end
