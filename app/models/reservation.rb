class Reservation < ApplicationRecord
  belongs_to :exchange
  belongs_to :variant
  belongs_to :location
end
