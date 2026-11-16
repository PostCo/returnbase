# Turns each reservation into a shipped replacement: stock leaves the location and the hold is released.
# An exchange whose item was rejected is destroyed instead, which releases its hold.
class ReturnOrders::FulfilExchangesService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    exchanges = return_order.exchanges.reserved.includes(:reservations, :return_item).to_a
    rejected, shipped = exchanges.partition { |exchange| exchange.return_item&.rejected? }
    rejected.each(&:destroy!)
    shipped.each { |exchange| fulfil(exchange) }
    ReturnMailer.exchanged(return_order).deliver_now if shipped.any?
    result(success: true, payload: shipped)
  end

  private

  attr_reader :return_order

  def fulfil(exchange)
    exchange.reservations.each do |reservation|
      level = InventoryLevel.find_by!(variant: reservation.variant, location: reservation.location)
      level.update!(available: [level.available - reservation.quantity, 0].max)
    end
    exchange.reservations.destroy_all
    exchange.fulfilled!
    return_order.record_event(:exchange_fulfilled, variant_id: exchange.variant_id, quantity: exchange.quantity)
  end
end
