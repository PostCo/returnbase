require_relative "lib/store_box"
require_relative "lib/parcel_dock"
require_relative "lib/quick_post"

class Vendors < Sinatra::Base
  set :host_authorization, { permitted_hosts: [] } # reachable as "vendors" from other containers

  get "/health" do
    content_type :json
    { status: "ok", service: "vendors" }.to_json
  end

  get "/" do
    links = State::NAMES.map do |n|
      "<li>#{VendorLayout.wordmark(n)}" \
        "<a href='/#{n}/console'>Console</a><a href='/#{n}/log'>Request log</a></li>"
    end.join
    body = "<ul class='vendor-list'>#{links}</ul><form method='post' action='/reset'><button class='btn ghost'>Reset all vendors</button></form>"
    VendorLayout.render(vendor: :index, title: "Fake vendors", body:)
  end

  post "/reset" do
    State.reset_all
    content_type :json
    { status: "reset" }.to_json
  end
end

APP = Rack::URLMap.new(
  "/storebox" => StoreBox,
  "/parceldock" => ParcelDock,
  "/quickpost" => QuickPost,
  "/" => Vendors
)
