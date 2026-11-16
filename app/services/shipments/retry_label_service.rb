class Shipments::RetryLabelService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    raise Failure, "Only a failed label can be requested again" unless return_order.shipment&.label_failed?

    Shipments::CreateRemoteOrderService.call!(return_order: return_order)
  end

  private

  attr_reader :return_order
end
