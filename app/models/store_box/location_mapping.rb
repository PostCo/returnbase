# Which StoreBox warehouse a return location sends to. The location's store_box_warehouse flag is set alongside it.
class StoreBox::LocationMapping < ApplicationRecord
  belongs_to :store_box_integration
  belongs_to :location

  validates :warehouse_id, presence: true
end
