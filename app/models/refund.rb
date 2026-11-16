# Simulated: no payment provider is called.
class Refund < ApplicationRecord
  belongs_to :return_order

  monetize :amount_cents, with_model_currency: :currency
end
