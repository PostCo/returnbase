module Api
  # Base for merchant endpoints: every one needs a signed-in user and is scoped to that user's shop.
  class BaseController < ApplicationController
    before_action :require_login

    rescue_from(ActiveRecord::RecordNotFound) { render json: { errors: ["Not found"] }, status: :not_found }

    private

    def current_user
      @current_user ||= User.find_by(id: cookies.signed[:user_id])
    end

    def current_shop
      current_user&.shop
    end

    def require_login
      render json: { errors: ["Not logged in"] }, status: :unauthorized unless current_user
    end

    def session_json
      { user: { email: current_user.email }, shop: { id: current_shop.id, name: current_shop.name } }
    end
  end
end
