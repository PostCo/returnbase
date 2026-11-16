require_relative "test_helper"

class MountedAppTest < VendorTest
  def app = Rack::Lint.new(APP)

  def test_vendors_answer_under_their_mount_paths_with_a_strict_rack_input
    get "/health"
    assert_equal 200, last_response.status
    get "/storebox/account", {}, "HTTP_X_API_KEY" => StoreBox::API_KEY
    assert_equal 200, last_response.status
    post "/quickpost/admin/scenario", scenario: "temporary_failure"
    assert_equal "temporary_failure", body["scenario"]
    post_json "/quickpost/labels", { reference: "R", to: { name: "S" } }, "HTTP_AUTHORIZATION" => "Bearer k"
    assert_equal 503, last_response.status
  end

  def test_every_page_carries_the_sandbox_banner_and_its_vendors_brand
    ["/", "/storebox/console", "/storebox/log", "/quickpost/console", "/quickpost/log", "/parceldock/console", "/parceldock/log"].each do |path|
      get path
      assert_includes last_response.body, "Sandbox, simulated vendor", path
    end
    get "/quickpost/console"
    assert_includes last_response.body, "m-quickpost"
  end

  def test_scenario_buttons_work_as_a_plain_form
    post "/parceldock/admin/scenario", scenario: "temporary_failure", _back: "1"
    assert_equal 302, last_response.status
    get "/parceldock/console"
    assert_includes last_response.body, "aria-pressed='true'>temporary_failure"
  end
end
