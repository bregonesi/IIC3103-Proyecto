Spree::OrderContents.class_eval do
    def remove(variant, quantity = 1, options = {})
    	puts "ejecutando func"
      ActiveRecord::Base.transaction do
        line_item = remove_from_line_item(variant, quantity, options)
        after_add_or_remove(line_item, options)
      end
    end
end