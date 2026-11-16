require_relative "vendor_app"

# A label carrier: creates a parcel with a tracking number, reports its status, and has a console to move it along.
class LabelVendor < VendorApp
  set :scenarios, %w[normal temporary_failure]

  EVENTS = {
    "picked_up" => { from: "label_created", to: "picked_up" },
    "delivered" => { from: "picked_up", to: "delivered" }
  }.freeze

  before do
    authenticate! if api_request? && !request.path_info.start_with?("/labels/")
  end

  get "/tracking/:number" do
    parcel = state.data[params[:number]]
    fail_with(404, "not_found", "No parcel with that tracking number.") unless parcel
    reply 200, tracking_number: parcel[:tracking_number], status: parcel[:status], events: parcel[:events]
  end

  get "/labels/:number" do
    parcel = state.data[params[:number]]
    halt 404, "No such label" unless parcel
    content_type :html
    "<!doctype html><title>#{h(settings.vendor_title)} label</title><body style='font: 20px monospace; border: 3px solid #000; padding: 1rem; width: 24rem'>" \
      "<b>#{h(settings.vendor_title)}</b><br>#{h(parcel[:tracking_number])}<br>To: #{h(parcel[:recipient_name])}<br>Ref: #{h(parcel[:reference])}</body>"
  end

  get "/console" do
    rows = state.data.values.map do |p|
      buttons = EVENTS.select { |_, t| t[:from] == p[:status] }.keys.map do |event|
        "<form method='post' action='#{path_to("/console/parcels/#{p[:tracking_number]}/#{event}")}'><button>Mark #{event.tr('_', ' ')}</button></form>"
      end.join
      "<tr><td>#{h(p[:tracking_number])}</td><td>#{h(p[:reference])}</td><td>#{pill(p[:status])}</td><td>#{buttons}</td></tr>"
    end
    page("Console", data_table(%w[Tracking Reference Status Action], rows, empty: "No labels have been bought from #{settings.vendor_title} yet."))
  end

  post "/console/parcels/:number/:event" do
    transition = EVENTS[params[:event]] or halt(404)
    changed = false
    parcel = nil
    state.synchronize do
      parcel = state.data[params[:number]]
      if parcel && parcel[:status] == transition[:from]
        parcel[:status] = transition[:to]
        parcel[:events] << { status: transition[:to], at: now }
        changed = true
      end
    end
    notify(params[:event], parcel) if changed
    redirect path_to("/console")
  end

  helpers do
    def notify(_event, _parcel); end

    def create_parcel(reference:, recipient_name:, **extra)
      state.synchronize do
        n = state.next_seq
        tracking = format("%s%08d", settings.prefix, n)
        state.data[tracking] = {
          id: "#{settings.id_prefix}_#{n}", reference:, recipient_name:, tracking_number: tracking, status: "label_created",
          label_url: "#{settings.public_base_url}#{settings.mount_path}/labels/#{tracking}",
          created_at: now, events: [{ status: "label_created", at: now }]
        }.merge(extra)
      end
    end

    def present_parcel(parcel) = parcel.except(:recipient_name, :events)
  end
end
