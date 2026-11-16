class ReturnOrders::ReceiveService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    raise Failure, "This return cannot be received yet" unless return_order.can_receive?

    ReturnOrder.transaction do
      return_order.receive!
      return_order.shipment&.delivered!
    end
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order
end
