require_relative "test_helper"

class StoreBoxTest < VendorTest
  KEY = { "HTTP_X_API_KEY" => StoreBox::API_KEY }.freeze
  RETURN = { reference: "RET-1", warehouse_id: "wh_rtm", items: [{ sku: "JACKET-M", quantity: 1, reason: "too small" }] }.freeze

  def app = StoreBox

  def create_return = post_json("/returns", RETURN, KEY)

  def test_account_accepts_the_key
    get "/account", {}, KEY
    assert_equal 200, last_response.status
    assert_equal "acct_demo", body.dig("account", "id")
  end

  def test_rejects_a_wrong_or_missing_key
    get "/account", {}, "HTTP_X_API_KEY" => "nope"
    assert_equal 401, last_response.status
    get "/warehouses"
    assert_equal 401, last_response.status
  end

  def test_invalid_credentials_scenario_rejects_the_right_key
    post "/admin/scenario", scenario: "invalid_credentials"
    get "/account", {}, KEY
    assert_equal 401, last_response.status
    assert_equal "invalid_credentials", body.dig("error", "code")
  end

  def test_lists_warehouses
    get "/warehouses", {}, KEY
    assert_equal %w[wh_rtm wh_lds wh_dub], body["warehouses"].map { |w| w["id"] }
  end

  def test_create_returns_201_with_an_id_and_pending_status
    create_return
    assert_equal 201, last_response.status
    assert_equal "pending", body["status"]
    assert_match(/\Asbr_/, body["id"])
  end

  def test_create_twice_makes_two_returns
    create_return
    first = body["id"]
    create_return
    refute_equal first, body["id"]
  end

  def test_create_validates_the_payload
    post_json "/returns", RETURN.merge(warehouse_id: "wh_nope", items: []), KEY
    assert_equal 422, last_response.status
    assert_equal 2, body.dig("error", "details").size
  end

  def test_create_rejects_invalid_json
    post "/returns", "not json", KEY.merge("CONTENT_TYPE" => "application/json")
    assert_equal 400, last_response.status
  end

  def test_temporary_failure_scenario_fails_create_and_stores_nothing
    post "/admin/scenario", scenario: "temporary_failure"
    create_return
    assert_equal 503, last_response.status
    assert_equal "30", last_response.headers["Retry-After"]
    post "/admin/scenario", scenario: "normal"
    get "/returns/sbr_1", {}, KEY
    assert_equal 404, last_response.status
  end

  def test_return_goes_from_pending_to_received_to_inspected_through_the_console
    create_return
    id = body["id"]
    post "/console/returns/#{id}/receive"
    get "/returns/#{id}", {}, KEY
    assert_equal "received", body["status"]
    assert body["received_at"]

    post "/console/returns/#{id}/inspect", results: ["damaged"]
    get "/returns/#{id}", {}, KEY
    assert_equal "inspected", body["status"]
    assert_equal "damaged", body["items"].first["result"]
  end

  def test_inspect_before_receipt_changes_nothing
    create_return
    post "/console/returns/#{body['id']}/inspect", results: ["restock"]
    get "/returns/sbr_1", {}, KEY
    assert_equal "pending", body["status"]
  end

  def test_unknown_return_is_404
    get "/returns/sbr_99", {}, KEY
    assert_equal 404, last_response.status
  end

  def test_requests_are_logged_and_reset_clears_them
    create_return
    get "/log.json"
    entry = body["requests"].last
    assert_equal ["POST", "/returns", 201], [entry["method"], entry["path"], entry["status"]]
    post "/admin/reset"
    get "/log.json"
    assert_empty body["requests"]
    get "/returns/sbr_1", {}, KEY
    assert_equal 404, last_response.status
  end

  def test_pages_render
    create_return
    get "/console"
    assert_includes last_response.body, "Mark received"
    get "/log"
    assert_includes last_response.body, "/returns"
  end
end
