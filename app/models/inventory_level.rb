class InventoryLevel < ApplicationRecord
  belongs_to :variant
  belongs_to :location

  validates :available, numericality: { greater_than_or_equal_to: 0 }
end
