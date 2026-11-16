module Webhooks
  class ShippingController < ApplicationController
    TOKEN = ENV.fetch("SHIPPING_CALLBACK_TOKEN", "dev-shipping-token")

    before_action :check_token

    def create
      shipment = Shipment.pending.find_by(label_request_id: params[:id])
      return render json: { errors: ["No pending label request #{params[:id]}"] }, status: :unprocessable_entity unless shipment

      outcome = settle(shipment)
      if outcome&.success?
        head :ok
      else
        render json: { errors: outcome ? outcome.errors.full_messages : ["Unknown status"] }, status: :unprocessable_entity
      end
    end

    private

    def check_token
      return if ActiveSupport::SecurityUtils.secure_compare(request.headers["X-Shipping-Token"].to_s, TOKEN)

      head :unauthorized
    end

    def settle(shipment)
      case params[:status]
      when "created"
        Shipments::LabelCreatedService.call(
          shipment: shipment, carrier: params[:carrier], tracking_number: params[:tracking_number], label_url: params[:label_url],
        )
      when "failed"
        Shipments::LabelFailedService.call(shipment: shipment, error: params[:error].to_s)
      end
    end
  end
end
