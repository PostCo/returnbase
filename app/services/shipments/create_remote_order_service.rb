# Asks the shipping team's label service for a label. QuickPost sells the label, unless the shop has ParcelDock enabled:
# then ParcelDock sells it. The label comes back by callback: Shipments::LabelCreatedService finishes a label return and
# hands it to the warehouse, Shipments::LabelFailedService records a refusal.
class Shipments::CreateRemoteOrderService < ApplicationService
  CALLBACK_URL = ENV.fetch("SHIPPING_CALLBACK_URL", "http://api:3100/webhooks/shipping")

  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    request = ShippingClient.new.request_label(
      reference: return_order.number, carrier: carrier, carrier_api_key: parcel_dock&.api_key,
      recipient_name: return_order.customer.name, callback_url: CALLBACK_URL,
    )
    shipment.update!(status: :pending, label_request_id: request["id"], error: nil)
    return_order.record_event(:label_requested, carrier: carrier)
    result(success: true, payload: shipment)
  rescue VendorClient::Error => e
    Shipments::LabelFailedService.call!(shipment: shipment, error: "Could not request the label: #{e.message}")
    result(success: true, payload: shipment)
  end

  private

  attr_reader :return_order

  def shipment
    @shipment ||= return_order.shipment || return_order.build_shipment
  end

  def parcel_dock
    integration = return_order.shop.parcel_dock_integration
    integration if integration&.enabled?
  end

  def carrier
    parcel_dock ? "parceldock" : "quickpost"
  end
end
