module Api
  class MeController < BaseController
    def show
      render json: session_json
    end
  end
end
