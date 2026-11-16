# Rejects a submitted return, or a received one by rejecting each of its items.
class ReturnOrders::RejectService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    raise Failure, "Only submitted or received returns can be rejected" unless return_order.can_reject?

    if return_order.received?
      decisions = return_order.items.map { |item| { item_id: item.id, outcome: "rejected" } }
      ReturnOrders::ResolveService.call!(return_order: return_order, decisions: decisions)
    else
      return_order.reject!
      ReturnMailer.rejected(return_order).deliver_now
    end
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order
end
