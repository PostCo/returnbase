class Shipments::PickedUpService < ApplicationService
  def initialize(tracking_number:)
    @tracking_number = tracking_number
  end

  def call
    shipment = Shipment.find_by(tracking_number: tracking_number)
    raise Failure, "No shipment with tracking number #{tracking_number}" unless shipment

    return_order = shipment.return_order
    ReturnOrder.transaction do
      shipment.picked_up!
      return_order.record_event(:carrier_event, event: "picked_up", tracking_number: tracking_number)
      return_order.mark_in_transit! if return_order.can_mark_in_transit?
    end

    ReturnOrders::AfterPickedUpService.call!(return_order: return_order)
    result(success: true, payload: shipment)
  end

  private

  attr_reader :tracking_number
end
