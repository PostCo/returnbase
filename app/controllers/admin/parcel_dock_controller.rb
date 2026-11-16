module Admin
  # Support's setup page for ParcelDock. Merchants have no ParcelDock settings page; their Integrations page says to
  # contact support.
  class ParcelDockController < ActionController::Base
    http_basic_authenticate_with name: "admin", password: ENV.fetch("ADMIN_PASSWORD", "returnbase-admin")
    skip_forgery_protection
    layout "admin"

    def index
      @shops = Shop.includes(:parcel_dock_integration, :locations).order(:name)
    end

    def update
      @notice = save_parcel_dock(Shop.find(params[:shop_id]))
      index
      render :index
    end

    private

    def save_parcel_dock(shop)
      integration = shop.parcel_dock_integration || shop.build_parcel_dock_integration
      Shop.transaction do
        integration.update!(api_key: params[:api_key].presence || integration.api_key, status: params[:enabled] ? :enabled : :disabled)
        shop.locations.each { |location| location.update!(parcel_dock_facility: location.id == params[:facility_location_id].to_i) }
      end
      "Saved ParcelDock for #{shop.name}"
    rescue ActiveRecord::RecordInvalid => e
      "Not saved: #{e.message}"
    end
  end
end
