require "net/http"
require_relative "label_vendor"

class QuickPost < LabelVendor
  set :vendor, :quickpost
  set :vendor_title, "QuickPost"
  set :prefix, "QP"
  set :id_prefix, "qpl"
  set :mount_path, "/quickpost"
  set :public_base_url, ENV.fetch("VENDORS_PUBLIC_URL", "http://localhost:4100")

  class << self
    attr_accessor :webhook_url, :webhook_sender

    def deliver(url, payload)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5) do |http|
        http.post(uri.request_uri, payload.to_json, "Content-Type" => "application/json", "X-QuickPost-Event" => payload[:event])
      end
      { status: response.code.to_i }
    rescue StandardError => e
      { error: e.message }
    end
  end

  self.webhook_url = ENV.fetch("QUICKPOST_WEBHOOK_URL", "http://api:3100/webhooks/quickpost")
  self.webhook_sender = method(:deliver)

  post "/labels" do
    unavailable_if_failing!
    to = payload["to"]
    unless payload["reference"].is_a?(String) && !payload["reference"].empty? && to.is_a?(Hash) && to["name"].is_a?(String)
      fail_with(422, "validation_failed", "reference and to.name are required.")
    end

    parcel = create_parcel(reference: payload["reference"], recipient_name: to["name"])
    reply 201, present_parcel(parcel)
  end

  helpers do
    def authenticate!
      return if request.env["HTTP_AUTHORIZATION"].to_s.match?(/\ABearer \S+/)

      fail_with(401, "unauthorized", "Send your key as a Bearer token.")
    end

    def notify(event, parcel)
      body = { event: "parcel.#{event}", tracking_number: parcel[:tracking_number], reference: parcel[:reference],
               status: parcel[:status], occurred_at: now }
      url = self.class.webhook_url
      result = self.class.webhook_sender.call(url, body)
      state.record(direction: "out", method: "POST", path: url, body: body.to_json, status: result[:status] || "error: #{result[:error]}")
    end
  end
end
