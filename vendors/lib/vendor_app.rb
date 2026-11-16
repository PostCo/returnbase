require "json"
require "time"
require "sinatra/base"
require_relative "state"
require_relative "vendor_layout"

# Shared behaviour of the three fake vendors: request log, scenario switch, reset, JSON helpers and pages.
class VendorApp < Sinatra::Base
  set :host_authorization, { permitted_hosts: [] } # reachable as "vendors" from other containers
  set :protection, false
  set :show_exceptions, false

  before do
    @raw_body = form_request? ? params.to_json : request.body&.read.to_s
  end

  after do
    next unless api_request?

    state.record(direction: "in", method: request.request_method, path: request.script_name + request.path_info,
                 query: request.query_string, body: @raw_body, status: response.status)
  end

  helpers do
    def state = State.for(settings.vendor)
    def h(value) = Rack::Utils.escape_html(value.to_s)
    def path_to(path) = "#{request.script_name}#{path}"
    def api_request? = !request.path_info.match?(%r{\A/(console|admin|log)(\z|[/.])})
    def now = Time.now.utc.iso8601
    def form_request? = %w[application/x-www-form-urlencoded multipart/form-data].include?(request.media_type)

    def reply(status, body = {})
      halt status, { "content-type" => "application/json" }, body.to_json
    end

    def fail_with(status, code, message, details = nil)
      error = { code:, message: }
      error[:details] = details if details
      reply(status, error:)
    end

    def payload
      @payload ||= begin
        parsed = JSON.parse(@raw_body)
        parsed.is_a?(Hash) ? parsed : raise(JSON::ParserError)
      rescue JSON::ParserError
        fail_with(400, "invalid_json", "The request body must be a JSON object.")
      end
    end

    def unavailable_if_failing!
      return unless state.scenario == "temporary_failure"

      headers "Retry-After" => "30"
      fail_with(503, "temporary_failure", "#{settings.vendor_title} is temporarily unavailable. Retry shortly.")
    end

    # The scenario switch is a row of submit buttons, so it works without JavaScript.
    def page(title, body)
      scenarios = settings.scenarios.map do |name|
        "<button name='scenario' value='#{name}' aria-pressed='#{name == state.scenario}'>#{name}</button>"
      end.join
      controls = <<~HTML
        <form method="post" action="#{path_to('/admin/scenario')}">
          <input type="hidden" name="_back" value="1">
          <span class="label">Scenario</span><div class="seg">#{scenarios}</div>
        </form>
        <form method="post" action="#{path_to('/admin/reset')}">
          <input type="hidden" name="_back" value="1"><button class="btn ghost">Reset</button>
        </form>
      HTML
      tabs = [["Console", path_to("/console"), title == "Console"], ["Request log", path_to("/log"), title == "Request log"]]
      VendorLayout.render(vendor: settings.vendor, title:, body:, tabs:, controls:, root: request.script_name.sub(%r{/[^/]*\z}, ""))
    end

    def data_table(headers, rows, empty:)
      return "<div class='empty'>#{h(empty)}</div>" if rows.empty?

      "<div class='scroll'><table><tr>#{headers.map { |header| "<th>#{h(header)}</th>" }.join}</tr>#{rows.join}</table></div>"
    end

    def pill(text, kind = text) = "<span class='st st-#{h(kind.to_s.tr('_', '-'))}'>#{h(text)}</span>"
  end

  get "/log.json" do
    reply 200, requests: state.log
  end

  get "/log" do
    rows = state.log.reverse.map do |e|
      outcome = e[:status].to_s.match?(/\A[23]/) ? "ok" : "bad"
      "<tr><td>#{h(e[:at])}</td><td>#{pill(e[:direction])}</td><td>#{h(e[:method])} #{h(e[:path])}#{h("?#{e[:query]}") unless e[:query].to_s.empty?}</td>" \
        "<td>#{pill(e[:status], outcome)}</td><td><pre>#{h(e[:body])}</pre></td></tr>"
    end
    page("Request log", data_table(%w[Time Dir Request Status Body], rows, empty: "No requests yet."))
  end

  post "/admin/reset" do
    state.reset
    params["_back"] ? redirect(path_to("/console")) : reply(200, scenario: state.scenario)
  end

  post "/admin/scenario" do
    name = request.media_type == "application/json" ? payload["scenario"] : params["scenario"]
    fail_with(422, "unknown_scenario", "Scenario must be one of #{settings.scenarios.join(', ')}.") unless settings.scenarios.include?(name)
    state.scenario = name
    params["_back"] ? redirect(path_to("/console")) : reply(200, scenario: state.scenario)
  end
end
