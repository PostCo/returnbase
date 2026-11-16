require "test_helper"

class MerchantApiTest < ActionDispatch::IntegrationTest
  include ReturnFixtures

  setup do
    build_return(kind: :own_postage)
    @shop.users.create!(email: "owner@test.example", password: "secret123")
  end

  test "me is 401 until the merchant signs in" do
    get "/api/me"
    assert_response :unauthorized

    post "/api/session", params: { email: "owner@test.example", password: "wrong" }, as: :json
    assert_response :unauthorized

    post "/api/session", params: { email: "OWNER@test.example", password: "secret123" }, as: :json
    assert_equal({ "user" => { "email" => "owner@test.example" }, "shop" => { "id" => @shop.id, "name" => "Test Shop" } }, response.parsed_body)

    get "/api/me"
    assert_response :success
  end

  test "actions return the detail JSON, 422 on a bad move, and 404 for another shop's return" do
    post "/api/session", params: { email: "owner@test.example", password: "secret123" }, as: :json

    post "/api/returns/#{@return_order.id}/approve"
    assert_response :success
    assert_equal "approved", response.parsed_body["status"]
    assert_includes response.parsed_body["allowed_actions"], "receive"

    post "/api/returns/#{@return_order.id}/approve"
    assert_response :unprocessable_entity
    assert_equal ["Only submitted returns can be approved"], response.parsed_body["errors"]

    other = Shop.create!(name: "Other")
    other_user = other.users.create!(email: "other@test.example", password: "secret123")
    delete "/api/session"
    post "/api/session", params: { email: other_user.email, password: "secret123" }, as: :json
    post "/api/returns/#{@return_order.id}/receive"
    assert_response :not_found
  end
end
