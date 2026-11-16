# Puts the accepted items the merchant chose to restock back into stock at the return location.
class ReturnOrders::RestockService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    to_restock, skipped = return_order.items.accepted.includes(:variant).partition(&:restock?)
    restocked = to_restock.map { |item| line(item).merge(available: add_stock(item)) }
    return_order.record_event(:restocked, restocked: restocked, skipped: skipped.map { |item| line(item) })
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order

  def add_stock(item)
    level = InventoryLevel.find_or_create_by!(variant: item.variant, location: return_order.location)
    level.increment!(:available, item.quantity).available
  end

  def line(item)
    { sku: item.variant.sku, quantity: item.quantity }
  end
end
