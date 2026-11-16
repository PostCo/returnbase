class Shipments::DeliveredService < ApplicationService
  def initialize(tracking_number:)
    @tracking_number = tracking_number
  end

  def call
    shipment = Shipment.find_by(tracking_number: tracking_number)
    raise Failure, "No shipment with tracking number #{tracking_number}" unless shipment

    shipment.delivered!
    shipment.return_order.record_event(:carrier_event, event: "delivered", tracking_number: tracking_number)
    result(success: true, payload: shipment)
  end

  private

  attr_reader :tracking_number
end
