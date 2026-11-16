module Api
  class SessionsController < BaseController
    skip_before_action :require_login

    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase)&.authenticate(params[:password].to_s)
      return render json: { errors: ["Invalid email or password"] }, status: :unauthorized unless user

      cookies.signed[:user_id] = { value: user.id, httponly: true, same_site: :lax }
      @current_user = user
      render json: session_json
    end

    def destroy
      cookies.delete(:user_id)
      head :no_content
    end
  end
end
