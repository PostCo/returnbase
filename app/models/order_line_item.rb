class OrderLineItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant

  monetize :price_cents, with_model_currency: :currency
end
