# Sends a return to another location before the parcel is on its way. An approved return takes its exchange
# stock with it, and a label return asks the label service for a new label.
class ReturnOrders::MoveService < ApplicationService
  def initialize(return_order:, location:)
    @return_order = return_order
    @location = location
  end

  def call
    raise Failure, "Only submitted or approved returns can be moved" unless return_order.movable?
    raise Failure, "Choose an active location" if location.shop_id != return_order.shop_id || location.archived?
    raise Failure, "The return is already at #{location.name}" if location == return_order.location

    from = return_order.location
    ReturnOrder.transaction do
      return_order.update!(location: location)
      return_order.record_event(:moved, from: from.name, to: location.name)
      next unless return_order.approved?

      ReturnOrders::ReserveExchangesService.call!(return_order: return_order)
      request_new_label if return_order.shipment
    end

    ReturnMailer.moved(return_order).deliver_now if return_order.approved? && return_order.own_postage?
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order, :location

  def request_new_label
    return_order.shipment.update!(label_url: nil, tracking_number: nil)
    Shipments::CreateRemoteOrderService.call!(return_order: return_order)
  end
end
