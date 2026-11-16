module Api
  class IntegrationsController < BaseController
    # One card per type on the Integrations page. The web app picks each card from its own map
    # (web/src/pages/integrations/cards.tsx).
    AVAILABLE_TYPES = %w[StoreBoxIntegration ParcelDockIntegration].freeze

    def index
      existing = current_shop.integrations.index_by(&:type)
      render json: { integrations: AVAILABLE_TYPES.map { |type| { type: type, status: existing[type]&.status } } }
    end
  end
end
