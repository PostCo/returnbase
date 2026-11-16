module Api
  class LocationsController < BaseController
    before_action :find_location, except: :index

    def index
      render_locations
    end

    def update = save(@location.update(params.permit(:name, :city, :address)), @location)
    def archive = save(@location.update(archived_at: Time.current), @location)
    def unarchive = save(@location.update(archived_at: nil), @location)
    def make_default = save(current_shop.update(default_location: @location), current_shop)

    private

    def find_location
      @location = current_shop.locations.find(params[:id])
    end

    def save(saved, record)
      if saved
        render_locations
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def render_locations
      locations = current_shop.locations.order(:name)
      render json: { locations: locations.map { |l| location_json(l) } }
    end

    def location_json(location)
      {
        id: location.id, name: location.name, city: location.city, address: location.address,
        archived: location.archived?, default: location.id == current_shop.default_location_id,
      }
    end
  end
end
