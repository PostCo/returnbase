# The label could not be requested or created. The shipment keeps the error and the merchant can request the label again.
class Shipments::LabelFailedService < ApplicationService
  def initialize(shipment:, error:)
    @shipment = shipment
    @error = error
  end

  def call
    shipment.update!(status: :label_failed, error: error)
    shipment.return_order.record_event(:label_failed, error: error)
    result(success: true, payload: shipment)
  end

  private

  attr_reader :shipment, :error
end
