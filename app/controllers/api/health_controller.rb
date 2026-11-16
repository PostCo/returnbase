module Api
  class HealthController < ApplicationController
    def show
      ActiveRecord::Base.connection.select_value("SELECT 1")
      render json: { status: "ok", database: "up" }
    rescue ActiveRecord::ActiveRecordError
      render json: { status: "error", database: "down" }, status: :service_unavailable
    end
  end
end
