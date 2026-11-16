class Shipment < ApplicationRecord
  belongs_to :return_order

  enum :status, {
    pending: 0,
    label_failed: 5,
    label_created: 10,
    picked_up: 20,
    delivered: 30,
  }
end
