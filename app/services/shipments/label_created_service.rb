# The shipping service created the label. Records it, emails the shopper, and only now hands the return to the warehouse.
# A return cancelled while its label was being made keeps the label on record, and nothing else happens.
class Shipments::LabelCreatedService < ApplicationService
  def initialize(shipment:, carrier:, tracking_number:, label_url:)
    @shipment = shipment
    @carrier = carrier
    @tracking_number = tracking_number
    @label_url = label_url
  end

  def call
    ReturnOrder.transaction do
      return_order.update!(location: facility) if facility
      shipment.update!(status: :label_created, tracking_number: tracking_number, label_url: label_url, error: nil)
      return_order.record_event(:shipment_created, tracking_number: tracking_number)
    end
    return result(success: true, payload: shipment) if return_order.cancelled?

    ReturnMailer.label_ready(return_order).deliver_now
    ReturnOrders::SendToWarehouseService.call!(return_order: return_order)
    result(success: true, payload: shipment)
  end

  private

  attr_reader :shipment, :carrier, :tracking_number, :label_url

  def return_order
    shipment.return_order
  end

  def facility
    return if carrier != "parceldock" || return_order.timeline_events.moved.exists?

    return_order.shop.parcel_dock_integration&.facility
  end
end
