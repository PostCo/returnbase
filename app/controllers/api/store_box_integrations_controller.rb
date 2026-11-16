module Api
  class StoreBoxIntegrationsController < BaseController
    before_action :set_integration, except: :create

    def show
      render_integration
    end

    def create
      form = StoreBoxIntegration::CreateForm.new(current_shop, params.permit(:api_key))
      form.submit ? render_integration(form.integration, status: :created) : render_errors(form)
    end

    def update
      submit StoreBoxIntegration::UpdateForm.new(@integration, params.permit(location_mappings: %i[location_id warehouse_id], result_mappings: %i[result action restock]))
    end

    def credentials
      submit StoreBoxIntegration::UpdateCredentialsForm.new(@integration, params.permit(:api_key))
    end

    def activate
      submit StoreBoxIntegration::ActivateForm.new(@integration)
    end

    def deactivate
      submit StoreBoxIntegration::DeactivateForm.new(@integration)
    end

    def warehouses
      render json: { warehouses: @integration.client.warehouses }
    rescue VendorClient::Error => e
      render json: { errors: ["Could not load StoreBox warehouses: #{e.message}"] }, status: :bad_gateway
    end

    private

    def set_integration
      @integration = current_shop.store_box_integration
      render json: { errors: ["StoreBox is not connected"] }, status: :not_found unless @integration
    end

    def submit(form)
      form.submit ? render_integration(@integration.reload) : render_errors(form)
    end

    def render_integration(integration = @integration, status: :ok)
      render json: StoreBoxIntegrationSerializer.new(integration).as_json, status: status
    end

    def render_errors(form)
      render json: { errors: form.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
