module Admin
  # Support's reset of the hosted demo, behind its own password.
  class DemoResetsController < ActionController::Base
    http_basic_authenticate_with name: "admin", password: ENV.fetch("ADMIN_PASSWORD", "returnbase-admin")
    skip_forgery_protection
    layout "admin"

    def create
      expected = ENV["DEMO_RESET_PASSWORD"].to_s
      if expected.present? && ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, expected)
        @reset = Demo::ResetService.call!.payload
      else
        render :refused, status: :forbidden
      end
    end
  end
end
