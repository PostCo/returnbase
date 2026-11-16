class ReturnOrders::AfterReviewService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    if return_order.label?
      # The label arrives later by callback, and Shipments::LabelCreatedService hands the return to the warehouse then.
      Shipments::CreateRemoteOrderService.call!(return_order: return_order)
    else
      # Own postage: no label, so the shopper gets posting instructions by email. Nothing creates
      # a shipment later, so the warehouse hears about the return now.
      ReturnOrders::SendToWarehouseService.call!(return_order: return_order)
    end
    result(success: true)
  end

  private

  attr_reader :return_order
end
