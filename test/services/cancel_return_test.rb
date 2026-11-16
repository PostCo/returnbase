require "test_helper"

class CancelReturnTest < ActiveSupport::TestCase
  include ReturnFixtures

  test "cancelling a submitted return records who cancelled and emails the shopper" do
    build_return

    outcome = ReturnOrders::CancelService.call(return_order: @return_order, cancelled_by: :shopper)

    assert outcome.success?, outcome.errors.full_messages.to_sentence
    assert @return_order.reload.cancelled?
    assert_equal "shopper", @return_order.timeline_events.cancelled.last.data["cancelled_by"]
    email = ReturnMailer.deliveries.last
    assert_equal ["ada@example.com"], email.to
    assert_includes email.body.to_s, "Please do not send the parcel"
  end

  test "cancelling an approved exchange releases its hold and keeps the label" do
    build_return(resolution: :exchange)
    approve_with_label
    assert_equal 1, Reservation.count

    assert ReturnOrders::CancelService.call(return_order: @return_order, cancelled_by: :merchant).success?

    assert @return_order.reload.cancelled?
    assert_empty @return_order.exchanges
    assert_equal 0, Reservation.count
    assert_equal "http://carrier.test/labels/R1001", @return_order.shipment.label_url
    assert_includes ReturnMailer.deliveries.last.body.to_s, "will not be used"
  end

  test "a return that is in transit or later cannot be cancelled" do
    build_return(kind: :own_postage)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    ReturnOrders::ReceiveService.call(return_order: @return_order)

    outcome = ReturnOrders::CancelService.call(return_order: @return_order, cancelled_by: :merchant)

    assert outcome.failed?
    assert_equal ["Only submitted or approved returns can be cancelled"], outcome.errors.full_messages
    assert @return_order.reload.received?
  end
end
