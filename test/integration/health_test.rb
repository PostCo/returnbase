require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /api/health reports the app and database are up" do
    get "/api/health"

    assert_response :success
    assert_equal({ "status" => "ok", "database" => "up" }, response.parsed_body)
  end
end
