class ReturnItem < ApplicationRecord
  belongs_to :return_order
  belongs_to :order_line_item
  belongs_to :variant
  belongs_to :exchange_variant, class_name: "Variant", optional: true
  has_many :exchanges, dependent: :nullify

  enum :reason, {
    too_small: 0,
    too_large: 1,
    damaged: 2,
    not_as_described: 3,
    changed_mind: 4,
  }

  enum :resolution, {
    refund: 0,
    exchange: 1,
  }

  # Set by whoever inspects the item, such as a warehouse. Empty until someone does.
  enum :condition, {
    restockable: 10,
    not_restockable: 20,
  }

  # The merchant's decision when the return is resolved. Empty until then.
  enum :outcome, {
    accepted: 10,
    rejected: 20,
  }

  validates :quantity, numericality: { greater_than: 0 }
  validates :exchange_variant, presence: true, if: :exchange?

  def restock_default
    return_order.shop.restock_on_resolve? && !not_restockable?
  end
end
