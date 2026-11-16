require_relative "label_vendor"

class ParcelDock < LabelVendor
  set :vendor, :parceldock
  set :vendor_title, "ParcelDock"
  set :prefix, "PD"
  set :id_prefix, "pds"
  set :mount_path, "/parceldock"
  set :public_base_url, ENV.fetch("VENDORS_PUBLIC_URL", "http://localhost:4100")

  FACILITY = "PD-01"

  post "/shipments" do
    unavailable_if_failing!
    recipient = payload["recipient"]
    unless payload["reference"].is_a?(String) && !payload["reference"].empty? && recipient.is_a?(Hash) && recipient["name"].is_a?(String)
      fail_with(422, "validation_failed", "reference and recipient.name are required.")
    end

    parcel = create_parcel(reference: payload["reference"], recipient_name: recipient["name"], facility: FACILITY)
    reply 201, present_parcel(parcel)
  end

  helpers do
    def authenticate!
      fail_with(401, "unauthorized", "Send your key in the X-Api-Key header.") if request.env["HTTP_X_API_KEY"].to_s.empty?
    end
  end
end
