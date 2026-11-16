ENV["RACK_ENV"] = "test"
require "minitest/autorun"
require "rack/test"
require "json"
require_relative "../app"

class VendorTest < Minitest::Test
  include Rack::Test::Methods

  def setup = State.reset_all

  def post_json(path, body, headers = {})
    post path, body.to_json, { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  def body = JSON.parse(last_response.body)
end
