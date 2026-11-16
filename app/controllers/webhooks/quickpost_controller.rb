module Webhooks
  class QuickpostController < ApplicationController
    SERVICES = {
      "parcel.picked_up" => Shipments::PickedUpService,
      "parcel.delivered" => Shipments::DeliveredService,
    }.freeze

    def create
      service = SERVICES[params[:event]]
      return render json: { errors: ["Unknown event"] }, status: :unprocessable_entity unless service

      outcome = service.call(tracking_number: params[:tracking_number])
      if outcome.success?
        head :ok
      else
        render json: { errors: outcome.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
