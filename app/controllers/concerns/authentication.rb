module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      return Current.session if Current.session
      record = find_session_by_cookie
      if record&.homebase?
        unless HomebaseSettings.enabled? && HomebaseSessionVerifier.valid?(record)
          record.destroy!
          cookies.delete(:session_id)
          return nil
        end
      end
      Current.session = record
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to new_session_path
    end

    def after_authentication_url
      HomebaseSettings.safe_path(session.delete(:return_to_after_authenticating))
    end

    def start_new_session_for(user, homebase: {})
      organization_id = session[:organization_id]
      reset_session
      session[:organization_id] = organization_id if user.memberships.exists?(organization_id: organization_id)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip, **homebase).tap do |session|
        Current.session = session
        cookies.signed[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: request.ssl?, expires: homebase.empty? ? 20.years.from_now : 8.hours.from_now }
      end
    end

    def terminate_session
      Current.session&.destroy!
      Current.session = nil
      reset_session
      cookies.delete(:session_id)
    end
end
