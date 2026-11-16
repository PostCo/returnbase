require "test_helper"

class ShippingWebhookTest < ActionDispatch::IntegrationTest
  include ReturnFixtures

  setup do
    build_return
    approve_and_request_label
  end

  def callback(token: Webhooks::ShippingController::TOKEN, **body)
    post "/webhooks/shipping", params: { id: "lbl_1", reference: "R1001", carrier: "quickpost" }.merge(body), headers: { "X-Shipping-Token" => token }, as: :json
  end

  test "a created label callback stores the label" do
    callback(status: "created", tracking_number: "QP1", label_url: "http://carrier.test/labels/QP1")

    assert_response :success
    assert_equal "label_created", @return_order.reload.shipment.status
  end

  test "a failed label callback stores the error" do
    callback(status: "failed", error: "The carrier rejected the label request.")

    assert_response :success
    assert_equal "label_failed", @return_order.reload.shipment.status
  end

  test "a wrong token is refused, and so is a callback that was already settled" do
    callback(token: "nope", status: "failed", error: "x")
    assert_response :unauthorized
    assert_equal "pending", @return_order.reload.shipment.status

    callback(status: "failed", error: "x")
    callback(status: "created", tracking_number: "QP1", label_url: "http://carrier.test/labels/QP1")
    assert_response :unprocessable_entity
  end
end
