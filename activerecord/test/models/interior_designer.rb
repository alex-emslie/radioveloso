class InteriorDesigner < ActiveRecord::Base
  has_one :chef, as: :employable
end
