class ShippingMethod < ApplicationRecord
  belongs_to :shop

  enum :kind, {
    label: 0,
    own_postage: 1,
  }

  validates :name, presence: true
end
