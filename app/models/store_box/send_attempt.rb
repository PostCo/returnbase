# One failed attempt to create a return at StoreBox. A return with attempts and no StoreBox::Return shows as
# "StoreBox send failed" until a retry succeeds.
class StoreBox::SendAttempt < ApplicationRecord
  belongs_to :store_box_integration
  belongs_to :return_order
end
