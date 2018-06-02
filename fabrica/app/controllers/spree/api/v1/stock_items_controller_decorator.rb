module Spree
	module Api
		module V1
			StockItemsController.class_eval do

				def index
					#puts "params " + params[:q].to_s
					#scope son los stock items del almacen source creo
					#puts "dfs"
					#puts scope.ransack(params[:q]).result.inspect
					#puts params[:q][:variant_product_name_or_variant_sku_cont]
					variants = Spree::Variant.joins(:product).where("name LIKE ? OR sku LIKE ?", "%#{params[:q][:variant_product_name_or_variant_sku_cont]}%", "%#{params[:q][:variant_product_name_or_variant_sku_cont]}%")
					#puts scope.where(variant: variants, count_on_hand: 1..Float::INFINITY)
					#@stock_items = scope.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
					@stock_items = scope.where(variant: variants, count_on_hand: 1..Float::INFINITY).page(params[:page]).per(params[:per_page])
					respond_with(@stock_items)
				end

			end
		end
	end
end