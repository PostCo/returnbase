require "json"
require "sinatra/base"
require_relative "lib/store"
require_relative "lib/labels"
require_relative "lib/label_job"

# The shipping team's label service. Returnbase asks for a label and gets 202 at once. The label is created at the
# carrier in the background, and the result is sent to the requester's callback_url.
class Shipping < Sinatra::Base
  set :host_authorization, { permitted_hosts: [] } # reachable as "shipping" from other containers
  set :protection, false
  set :show_exceptions, false
  set :store, Store.new
  set :delay, Float(ENV.fetch("SHIPPING_DELAY", "2"))
  set :background, true

  CARRIERS = %w[quickpost parceldock].freeze

  helpers do
    def store = settings.store
    def h(value) = Rack::Utils.escape_html(value.to_s)

    def reply(status, body)
      halt status, { "content-type" => "application/json" }, body.to_json
    end

    def fail_with(status, code, message) = reply(status, error: { code:, message: })

    def payload
      parsed = JSON.parse(request.body.read)
      parsed.is_a?(Hash) ? parsed : raise(JSON::ParserError)
    rescue JSON::ParserError
      fail_with(400, "invalid_json", "The request body must be a JSON object.")
    end

    def missing_fields(body)
      required = %w[reference carrier recipient_name callback_url]
      required << "carrier_api_key" if body["carrier"] == "parceldock"
      required.reject { |field| body[field].is_a?(String) && !body[field].empty? }
    end
  end

  after do
    next unless request.path_info.start_with?("/labels")

    store.record(direction: "in", method: request.request_method, url: request.path_info, body: @request_body.to_s, status: response.status)
  end

  get "/health" do
    reply 200, status: "ok", service: "shipping"
  end

  post "/labels" do
    body = payload
    @request_body = body.except("carrier_api_key").to_json
    fail_with(422, "unknown_carrier", "carrier must be one of #{CARRIERS.join(', ')}.") unless CARRIERS.include?(body["carrier"])
    missing = missing_fields(body)
    fail_with(422, "validation_failed", "#{missing.join(', ')} required.") unless missing.empty?

    label = store.create(body.slice("reference", "carrier", "carrier_api_key", "recipient_name", "callback_url").transform_keys(&:to_sym))
    job = LabelJob.new(store, label[:id])
    settings.background ? Thread.new { sleep settings.delay; job.run } : job.run
    reply 202, id: label[:id], status: "pending"
  end

  get "/labels/:id" do
    label = store.find(params[:id]) or fail_with(404, "not_found", "No label request with that id.")
    reply 200, Labels.present(label)
  end

  get "/log.json" do
    reply 200, requests: store.log
  end

  post "/admin/reset" do
    store.reset
    redirect "/"
  end

  post "/admin/scenario" do
    scenario = request.media_type == "application/json" ? payload["scenario"] : params["scenario"]
    fail_with(422, "unknown_scenario", "Scenario must be one of #{Store::SCENARIOS.join(', ')}.") unless Store::SCENARIOS.include?(scenario)
    store.scenario = scenario
    redirect "/"
  end

  get "/" do
    options = Store::SCENARIOS.map { |name| "<option#{' selected' if name == store.scenario}>#{name}</option>" }.join
    labels = store.labels.reverse.map do |l|
      "<tr><td>#{h(l[:id])}</td><td>#{h(l[:reference])}</td><td>#{h(l[:carrier])}</td><td>#{h(l[:status])}</td>" \
        "<td>#{h(l[:tracking_number])}</td><td>#{h(l[:error])}</td></tr>"
    end.join
    entries = store.log.reverse.map do |e|
      "<tr><td>#{h(e[:at])}</td><td>#{h(e[:direction])}</td><td>#{h(e[:method])} #{h(e[:url])}</td><td>#{h(e[:status])}</td><td><pre>#{h(e[:body])}</pre></td></tr>"
    end.join
    <<~HTML
      <!doctype html>
      <html><head><meta charset="utf-8"><title>Shipping label service</title>
      <style>
        body { font: 14px system-ui, sans-serif; margin: 2rem; color: #222 }
        table { border-collapse: collapse; margin: 1rem 0 }
        td, th { border: 1px solid #ccc; padding: 4px 8px; text-align: left; vertical-align: top }
        form { display: inline-block; margin-right: 1rem }
        pre { margin: 0; white-space: pre-wrap }
      </style></head><body>
      <h1>Shipping label service</h1>
      <p>Owned by the shipping team. API: <code>POST /labels</code>, <code>GET /labels/:id</code>. The request log is also at <a href="/log.json">/log.json</a>.</p>
      <form method="post" action="/admin/scenario">Scenario <select name="scenario">#{options}</select> <button>Set</button></form>
      <form method="post" action="/admin/reset"><button>Reset</button></form>
      <h2>Label requests</h2>
      <table><tr><th>Id</th><th>Reference</th><th>Carrier</th><th>Status</th><th>Tracking</th><th>Error</th></tr>#{labels}</table>
      <h2>Request log</h2>
      <table><tr><th>Time</th><th>Dir</th><th>Request</th><th>Status</th><th>Body</th></tr>#{entries}</table>
      </body></html>
    HTML
  end
end
