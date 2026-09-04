module Platform
  class SessionsController < BaseController
    allow_unauthenticated_platform_access only: %i[new create]
    rate_limit to: 10, within: 3.minutes, only: :create,
      with: -> { redirect_to new_platform_session_path, alert: "Try again later." }

    def new
    end

    def create
      operator = PlatformOperator.authenticate_by(params.permit(:email_address, :password))
      if operator&.active?
        start_new_platform_session_for(operator)
        redirect_to after_platform_authentication_url
      else
        redirect_to new_platform_session_path, alert: "Try another email address or password."
      end
    end

    def destroy
      terminate_platform_session
      redirect_to new_platform_session_path, status: :see_other
    end
  end
end
