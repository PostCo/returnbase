require "test_helper"

class DemoResetTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", ENV.fetch("ADMIN_PASSWORD", "returnbase-admin")) }.freeze

  setup do
    @previous_password = ENV["DEMO_RESET_PASSWORD"]
    ENV["DEMO_RESET_PASSWORD"] = "reset-me"
    Shop.create!(name: "Stale Shop")
    @calls = []
    @outside = ->(method, url) { @calls << [method, url] }
  end

  teardown { ENV["DEMO_RESET_PASSWORD"] = @previous_password }

  test "a wrong password resets nothing and says so" do
    Demo::ResetService.stub(:request, @outside) { post "/admin/demo_reset", params: { password: "nope" }, headers: AUTH }

    assert_response :forbidden
    assert_includes response.body, "Nothing was reset"
    assert_equal ["Stale Shop"], Shop.pluck(:name)
    assert_empty @calls
  end

  test "the right password leaves freshly seeded shops and clears the three outside services" do
    Demo::ResetService.stub(:request, @outside) { post "/admin/demo_reset", params: { password: "reset-me" }, headers: AUTH }

    assert_response :success
    assert_equal ["Harbour & Pine", "Kopi Threads", "Lumen Home"], Shop.order(:name).pluck(:name)
    assert_equal [Net::HTTP::Post, Net::HTTP::Post, Net::HTTP::Delete], @calls.map(&:first)
    assert_equal %w[http://vendors:4100/reset http://shipping:4300/admin/reset http://mailpit:8125/api/v1/messages], @calls.map(&:last)
  end

  test "an outside service that cannot be reached is shown and the database stays reset" do
    unreachable = ->(_method, url) { raise "connection refused" if url.include?("mailpit") }
    Demo::ResetService.stub(:request, unreachable) { post "/admin/demo_reset", params: { password: "reset-me" }, headers: AUTH }

    assert_response :success
    assert_includes response.body, "Mailpit: could not be cleared (connection refused)"
    assert_equal 3, Shop.count
  end
end
