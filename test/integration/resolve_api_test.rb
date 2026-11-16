require "test_helper"

class ResolveApiTest < ActionDispatch::IntegrationTest
  include ReturnFixtures

  setup do
    build_return(kind: :own_postage, restock: true)
    @shop.users.create!(email: "owner@test.example", password: "secret123")
    ReturnOrders::ApproveService.call!(return_order: @return_order)
    ReturnOrders::ReceiveService.call!(return_order: @return_order)
    post "/api/session", params: { email: "owner@test.example", password: "secret123" }, as: :json
  end

  test "a received return offers resolve and reject, and its items carry their restock default" do
    get "/api/returns/#{@return_order.id}"

    assert_equal %w[reject resolve], response.parsed_body["allowed_actions"].sort
    item = response.parsed_body["items"].sole
    assert_nil item["outcome"]
    assert_nil item["restock"]
    assert_equal true, item["restock_default"]
  end

  test "resolve with items saves each decision" do
    item = @return_order.items.sole

    post "/api/returns/#{@return_order.id}/resolve", params: { items: [{ id: item.id, outcome: "accepted", restock: false }] }, as: :json

    assert_response :success
    assert_equal "resolved", response.parsed_body["status"]
    assert_equal ["accepted", false], response.parsed_body["items"].sole.values_at("outcome", "restock")
    assert_equal 2000, @return_order.refunds.sole.amount_cents
    assert_empty @small.inventory_levels
  end

  test "resolve with every item rejected ends the return rejected" do
    post "/api/returns/#{@return_order.id}/resolve", params: { items: [{ id: @return_order.items.sole.id, outcome: "rejected" }] }, as: :json

    assert_response :success
    assert_equal "rejected", response.parsed_body["status"]
  end

  test "resolve without items accepts every item with the defaults" do
    post "/api/returns/#{@return_order.id}/resolve"

    assert_response :success
    assert_equal ["accepted", true], response.parsed_body["items"].sole.values_at("outcome", "restock")
  end

  test "resolve with an item that is not on the return is refused" do
    post "/api/returns/#{@return_order.id}/resolve", params: { items: [{ id: 0, outcome: "accepted" }] }, as: :json

    assert_response :unprocessable_entity
    assert_equal ["Decide each item of the return exactly once"], response.parsed_body["errors"]
  end

  test "the export ends with each return's item outcomes" do
    get "/api/returns/export"
    assert_equal "", CSV.parse(response.body, headers: true).first["Items"].to_s

    ReturnOrders::ResolveService.call!(return_order: @return_order)
    get "/api/returns/export"
    assert_equal "1 accepted", CSV.parse(response.body, headers: true).first["Items"]
  end
end
