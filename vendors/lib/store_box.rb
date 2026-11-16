require_relative "vendor_app"

class StoreBox < VendorApp
  set :vendor, :storebox
  set :vendor_title, "StoreBox"
  set :scenarios, %w[normal invalid_credentials temporary_failure]

  API_KEY = "sb_test_key"
  RESULTS = %w[restock damaged wrong_item].freeze
  WAREHOUSES = [
    { id: "wh_rtm", name: "Rotterdam Main", country: "NL" },
    { id: "wh_lds", name: "Leeds Returns Hub", country: "GB" },
    { id: "wh_dub", name: "Dublin Fulfilment", country: "IE" }
  ].freeze

  before do
    next unless api_request?

    key = request.env["HTTP_X_API_KEY"]
    fail_with(401, "invalid_credentials", "The API key is missing or invalid.") if state.scenario == "invalid_credentials" || key != API_KEY
  end

  get "/account" do
    reply 200, account: { id: "acct_demo", name: "Demo Merchant", plan: "standard" }
  end

  get "/warehouses" do
    reply 200, warehouses: WAREHOUSES
  end

  post "/returns" do
    unavailable_if_failing!
    errors = validation_errors(payload)
    fail_with(422, "validation_failed", "The return is invalid.", errors) if errors.any?

    record = state.synchronize do
      id = "sbr_#{state.next_seq}"
      state.data[id] = {
        id:, reference: payload["reference"], warehouse_id: payload["warehouse_id"], status: "pending",
        items: payload["items"].map { |i| { sku: i["sku"], quantity: i["quantity"], reason: i["reason"], result: nil } },
        created_at: now, received_at: nil, inspected_at: nil
      }
    end
    reply 201, record
  end

  get "/returns/:id" do
    record = state.data[params[:id]]
    fail_with(404, "not_found", "No return with that id.") unless record
    reply 200, record
  end

  get "/console" do
    rows = state.data.values.map { |r| console_row(r) }
    page("Console", data_table(%w[Id Reference Warehouse Status Items Action], rows, empty: "No returns have been sent to StoreBox yet."))
  end

  post "/console/returns/:id/receive" do
    state.synchronize do
      record = state.data[params[:id]]
      if record && record[:status] == "pending"
        record[:status] = "received"
        record[:received_at] = now
      end
    end
    redirect path_to("/console")
  end

  post "/console/returns/:id/inspect" do
    results = Array(params["results"])
    state.synchronize do
      record = state.data[params[:id]]
      if record && record[:status] == "received" && results.size == record[:items].size && results.all? { |r| RESULTS.include?(r) }
        record[:items].each_with_index { |item, i| item[:result] = results[i] }
        record[:status] = "inspected"
        record[:inspected_at] = now
      end
    end
    redirect path_to("/console")
  end

  helpers do
    def validation_errors(body)
      errors = []
      errors << "reference is required" unless body["reference"].is_a?(String) && !body["reference"].empty?
      errors << "warehouse_id is unknown" unless WAREHOUSES.any? { |w| w[:id] == body["warehouse_id"] }
      items = body["items"]
      if !items.is_a?(Array) || items.empty?
        errors << "items must be a non-empty array"
      elsif items.any? { |i| !i.is_a?(Hash) || !i["sku"].is_a?(String) || !i["quantity"].is_a?(Integer) || i["quantity"] < 1 }
        errors << "each item needs a sku and a quantity of at least 1"
      end
      errors
    end

    def console_row(record)
      items = record[:items].map { |i| "#{h(i[:sku])} x#{h(i[:quantity])} #{h(i[:result])}" }.join("<br>")
      "<tr><td>#{h(record[:id])}</td><td>#{h(record[:reference])}</td><td>#{h(record[:warehouse_id])}</td><td>#{pill(record[:status])}</td><td>#{items}</td><td>#{console_action(record)}</td></tr>"
    end

    def console_action(record)
      case record[:status]
      when "pending"
        "<form method='post' action='#{path_to("/console/returns/#{record[:id]}/receive")}'><button>Mark received</button></form>"
      when "received"
        selects = record[:items].map do |i|
          "<label>#{h(i[:sku])} <select name='results[]'>#{RESULTS.map { |r| "<option>#{r}</option>" }.join}</select></label>"
        end.join
        "<form class='pick' method='post' action='#{path_to("/console/returns/#{record[:id]}/inspect")}'>#{selects}<div><button>Record results</button></div></form>"
      else ""
      end
    end
  end
end
