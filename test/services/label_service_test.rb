require "test_helper"

class LabelServiceTest < ActiveSupport::TestCase
  include ReturnFixtures
  include ActiveJob::TestHelper

  setup do
    build_return
    @shop.create_store_box_integration!(api_key: "sb_test_key", status: :active)
    @location.update!(store_box_warehouse: true)
  end

  def shipment_state = @return_order.reload.shipment.slice(:status, :error).values

  test "approval requests the label and does not send the return to the warehouse yet" do
    assert_no_enqueued_jobs { assert approve_and_request_label.success? }

    shipment = @return_order.reload.shipment
    assert_equal ["pending", "lbl_1"], [shipment.status, shipment.label_request_id]
    assert_equal "label_requested", @return_order.timeline_events.last.kind
  end

  test "when the label request fails, approval still succeeds and the shipment shows the error" do
    outcome = approve_and_request_label(ReturnFixtures::FakeShipping.new("shipping is down"))

    assert outcome.success?
    assert @return_order.reload.approved?
    assert_equal ["label_failed", "Could not request the label: shipping is down"], shipment_state
    assert_equal "label_failed", @return_order.timeline_events.last.kind
  end

  test "the label callback records the label, emails it and sends the return to the warehouse" do
    approve_and_request_label

    assert_enqueued_with(job: StoreBox::SendJob) { label_created(tracking_number: "QP1") }

    assert_equal ["label_created", "QP1"], @return_order.reload.shipment.slice(:status, :tracking_number).values
    assert_equal "Your prepaid label for return R1001", ReturnMailer.deliveries.last.subject
    assert_equal %w[label_requested shipment_created], @return_order.timeline_events.last(2).map(&:kind)
  end

  test "a label that arrives after the return was cancelled is kept, but neither emailed nor sent to the warehouse" do
    approve_and_request_label
    ReturnOrders::CancelService.call!(return_order: @return_order, cancelled_by: :merchant)
    ReturnMailer.deliveries.clear

    assert_no_enqueued_jobs { label_created(tracking_number: "QP2") }

    assert_equal ["label_created", "QP2"], @return_order.reload.shipment.slice(:status, :tracking_number).values
    assert_empty ReturnMailer.deliveries
  end

  test "a failed label can be requested again, once" do
    approve_and_request_label(ReturnFixtures::FakeShipping.new("shipping is down"))
    shipping = ReturnFixtures::FakeShipping.new

    outcome = ShippingClient.stub(:new, shipping) { Shipments::RetryLabelService.call(return_order: @return_order) }

    assert outcome.success?
    assert_equal ["pending", nil], shipment_state
    assert_equal 1, shipping.requests.size
    assert Shipments::RetryLabelService.call(return_order: @return_order).failed?
  end

  test "the callback for a failed label keeps the error on the shipment" do
    approve_and_request_label

    Shipments::LabelFailedService.call!(shipment: @return_order.reload.shipment, error: "The carrier rejected the label request.")

    assert_equal ["label_failed", "The carrier rejected the label request."], shipment_state
    assert_no_enqueued_jobs
  end
end
