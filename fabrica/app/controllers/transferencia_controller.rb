class TransferenciaController < ApplicationController
  before_action :set_transferencium, only: [:show, :edit, :update, :destroy]

  # GET /transferencia
  # GET /transferencia.json
  def index

    r = HTTParty.put(ENV['api_banco_url'] + "trx",
                        body: {origen: "5ad36945d6ed1f00049becb4",
                               destino: "5ad36945d6ed1f00049becb1",
                               monto: 1}.to_json,
                        headers: { 'Content-type': 'application/json'})
    puts r
    if r.code == 200
      body = JSON.parse(r.body)
      Transferencium.create(origen: body["origen"], destino: body["destino"], idtransferencia: body["_id"], monto: body["monto"], originator_type: "Prueba", originator_id: 1)
    end
    @transferencia = Transferencium.all

  end

  # GET /transferencia/1
  # GET /transferencia/1.json
  def show

  end

  # GET /transferencia/new
  def new
    @transferencium = Transferencium.new
  end

  # GET /transferencia/1/edit
  def edit
  end

  # POST /transferencia
  # POST /transferencia.json
  def create
    @transferencium = Transferencium.new(transferencium_params)

    respond_to do |format|
      if @transferencium.save
        format.html { redirect_to @transferencium, notice: 'Transferencium was successfully created.' }
        format.json { render :show, status: :created, location: @transferencium }
      else
        format.html { render :new }
        format.json { render json: @transferencium.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /transferencia/1
  # PATCH/PUT /transferencia/1.json
  def update
    respond_to do |format|
      if @transferencium.update(transferencium_params)
        format.html { redirect_to @transferencium, notice: 'Transferencium was successfully updated.' }
        format.json { render :show, status: :ok, location: @transferencium }
      else
        format.html { render :edit }
        format.json { render json: @transferencium.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /transferencia/1
  # DELETE /transferencia/1.json
  def destroy
    @transferencium.destroy
    respond_to do |format|
      format.html { redirect_to transferencia_url, notice: 'Transferencium was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_transferencium
      @transferencium = Transferencium.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def transferencium_params
      params.require(:transferencium).permit(:origen, :string, :destino, :monto, :idtransferencia, :string, :originator_type, :string, :originator_id, :integer)
    end
end
