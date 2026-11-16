class Exchange < ApplicationRecord
  belongs_to :return_order
  belongs_to :variant
  belongs_to :return_item, optional: true

  has_many :reservations, dependent: :destroy

  enum :status, { reserved: 0, fulfilled: 10 }
end
