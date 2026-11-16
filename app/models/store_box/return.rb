# StoreBox's copy of a return, created once StoreBox has answered with its id. StoreBox::PollJob keeps it current.
class StoreBox::Return < ApplicationRecord
  belongs_to :store_box_integration
  belongs_to :return_order

  enum :status, { pending: 0, received: 10, inspected: 20 }

  scope :open, -> { where(status: %i[pending received]) }
end
