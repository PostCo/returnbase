class ReturnOrders::ApproveService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    raise Failure, "Only submitted returns can be approved" unless return_order.can_approve?

    ReturnOrder.transaction do
      return_order.approve!
      ReturnOrders::ReserveExchangesService.call!(return_order: return_order)
      ReturnOrders::AfterReviewService.call!(return_order: return_order)
    end

    ReturnMailer.approved(return_order.reload).deliver_now
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order
end
