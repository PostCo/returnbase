require "test_helper"

class CancelReturnApiTest < ActionDispatch::IntegrationTest
  include ReturnFixtures

  setup do
    build_return(kind: :own_postage)
    ReturnOrders::ApproveService.call(return_order: @return_order)
  end

  test "a merchant cancels an approved return, once" do
    @shop.users.create!(email: "owner@test.example", password: "secret123")
    post "/api/session", params: { email: "owner@test.example", password: "secret123" }, as: :json
    get "/api/returns/#{@return_order.id}"
    assert_includes response.parsed_body["allowed_actions"], "cancel"

    post "/api/returns/#{@return_order.id}/cancel"
    assert_response :success
    assert_equal "cancelled", response.parsed_body["status"]
    assert_equal "merchant", response.parsed_body["timeline"].last["data"]["cancelled_by"]

    post "/api/returns/#{@return_order.id}/cancel"
    assert_response :unprocessable_entity
    assert_equal ["Only submitted or approved returns can be cancelled"], response.parsed_body["errors"]
  end

  test "a shopper cancels with the email on the order" do
    path = "/api/shopper/returns/#{@return_order.number}/cancel"

    get "/api/shopper/returns/#{@return_order.number}", params: { shop_id: @shop.id, email: "ada@example.com" }
    assert_equal true, response.parsed_body["can_cancel"]
    assert response.parsed_body["shipping"]["instructions"].present?

    post path, params: { shop_id: @shop.id, email: "someone@example.com" }, as: :json
    assert_response :not_found
    assert @return_order.reload.approved?

    post path, params: { shop_id: @shop.id, email: "Ada@Example.com" }, as: :json
    assert_response :success
    assert_equal "cancelled", response.parsed_body["status"]
    assert_equal false, response.parsed_body["can_cancel"]
    assert_nil response.parsed_body["shipping"]["instructions"]
    assert_equal "shopper", @return_order.timeline_events.cancelled.last.data["cancelled_by"]
  end

  test "a shopper cannot cancel once the parcel has arrived" do
    ReturnOrders::ReceiveService.call(return_order: @return_order)

    post "/api/shopper/returns/#{@return_order.number}/cancel", params: { shop_id: @shop.id, email: "ada@example.com" }, as: :json

    assert_response :unprocessable_entity
    assert @return_order.reload.received?
  end
end
