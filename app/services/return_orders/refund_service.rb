# Writes the simulated refund for the refund items that are not rejected. It records only what they total beyond refunds
# already recorded, so a return is not refunded twice, whether on pickup or on resolve, and an edit after pickup is settled
# on resolve. A pickup refund for an item rejected later is not taken back.
class ReturnOrders::RefundService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    items = return_order.items.refund.includes(:order_line_item).reject(&:rejected?)
    total = items.sum { |item| item.quantity * item.order_line_item.price_cents }
    cents = total - return_order.refunds.sum(:amount_cents)
    return result(success: true) unless cents.positive?

    refund = return_order.refunds.create!(amount_cents: cents, currency: return_order.shop.currency)
    return_order.record_event(:refunded, amount_cents: cents)
    ReturnMailer.refunded(return_order).deliver_now
    result(success: true, payload: refund)
  end

  private

  attr_reader :return_order
end
