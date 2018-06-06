class OcsGenerada < ApplicationRecord
  belongs_to :oc_request

  validates_uniqueness_of :oc_request_id, :scope => :grupo
end
