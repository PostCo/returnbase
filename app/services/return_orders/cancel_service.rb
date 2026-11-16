class ReturnOrders::CancelService < ApplicationService
  CANCELLERS = %i[merchant shopper].freeze

  def initialize(return_order:, cancelled_by:)
    @return_order = return_order
    @cancelled_by = cancelled_by
  end

  def call
    raise ArgumentError, "cancelled_by must be one of #{CANCELLERS.to_sentence}" unless CANCELLERS.include?(cancelled_by)
    raise Failure, "Only submitted or approved returns can be cancelled" unless return_order.can_cancel?

    ReturnOrder.transaction do
      return_order.cancel!
      return_order.exchanges.destroy_all
      return_order.record_event(:cancelled, cancelled_by: cancelled_by)
    end

    ReturnMailer.cancelled(return_order.reload).deliver_now
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order, :cancelled_by
end
