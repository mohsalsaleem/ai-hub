module PlatformAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_platform_authentication
    helper_method :platform_authenticated?, :current_platform_operator
  end

  class_methods do
    def allow_unauthenticated_platform_access(**options)
      skip_before_action :require_platform_authentication, **options
    end
  end

  private

  def platform_authenticated?
    resume_platform_session
  end

  def current_platform_operator
    Current.platform_operator
  end

  def require_platform_authentication
    resume_platform_session || request_platform_authentication
  end

  def resume_platform_session
    Current.platform_session ||= find_platform_session_by_cookie
  end

  def find_platform_session_by_cookie
    return unless cookies.signed[:platform_session_id]

    platform_session = PlatformSession.includes(:platform_operator)
      .find_by(id: cookies.signed[:platform_session_id])
    return platform_session if platform_session&.platform_operator&.active?

    platform_session&.destroy
    nil
  end

  def request_platform_authentication
    session[:return_to_after_platform_authenticating] = request.url
    redirect_to new_platform_session_path
  end

  def after_platform_authentication_url
    session.delete(:return_to_after_platform_authenticating) || platform_root_url
  end

  def start_new_platform_session_for(operator)
    operator.platform_sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |platform_session|
      Current.platform_session = platform_session
      cookies.signed.permanent[:platform_session_id] = {
        value: platform_session.id, httponly: true, same_site: :lax
      }
    end
  end

  def terminate_platform_session
    Current.platform_session&.destroy
    cookies.delete(:platform_session_id)
  end
end
