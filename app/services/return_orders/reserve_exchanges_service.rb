# Holds stock at the return location for each exchange item. Safe to run again after an edit.
class ReturnOrders::ReserveExchangesService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    return_order.exchanges.destroy_all
    return_order.items.exchange.each { |item| reserve(item) }
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order

  def reserve(item)
    variant = item.exchange_variant
    location = return_order.location
    on_hand = InventoryLevel.find_by(variant: variant, location: location)&.available.to_i
    held = Reservation.where(variant: variant, location: location).sum(:quantity)
    raise Failure, "Not enough stock of #{variant.display_name} at #{location.name}" if on_hand - held < item.quantity

    exchange = return_order.exchanges.create!(variant: variant, quantity: item.quantity, return_item: item)
    exchange.reservations.create!(variant: variant, location: location, quantity: item.quantity)
    return_order.record_event(:exchange_reserved, variant_id: variant.id, quantity: item.quantity)
  end
end
