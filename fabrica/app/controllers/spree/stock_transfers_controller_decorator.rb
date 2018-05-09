module Spree
	Admin::StockTransfersController.class_eval do
		def create  # esta bugeada, la arreglamos
	    if params[:variant].nil?
	      flash[:error] = Spree.t('stock_transfer.errors.must_have_variant')
	      render :new
	    elsif destination_location.proposito == "Pulmon" # esto es agregado
	      flash[:error] = Spree.t('Almacen destino no puede ser almacen pulmon.')
	      render :new
	    else # hasta aqui es agregado
	      variants = Hash.new(0)
	      params[:variant].each_with_index do |variant_id, i|
	      	# esto es agregado
	      	if params[:quantity][i].to_i > source_location.stock_items.find_by(variant: variant_id).count_on_hand
			      flash[:error] = Spree.t('Variant ' + variant_id + ' sin stock suficiente.')
			      return render :new
			    end
			    # hasta aqui es agregado

	        variants[variant_id] += params[:quantity][i].to_i
	      end

	      # esto es agregado
	      if destination_location.available_capacity < variants.values.sum
		      flash[:error] = Spree.t('Excede capacidad de destino; Capacidad restante destino: ' + destination_location.available_capacity.to_s + '.')
		      return render :new
		    end
		    # hasta aqui es agregado

	      stock_transfer = StockTransfer.create(reference: params[:reference])
	      stock_transfer.transfer(source_location,
	                              destination_location,
	                              variants)

	      flash[:success] = Spree.t(:stock_successfully_transferred)
	      redirect_to admin_stock_transfer_path(stock_transfer)
	    end
	  end

	end

end