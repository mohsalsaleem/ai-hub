class HomebaseController < ApplicationController
  allow_unauthenticated_access only: %i[login callback]
  skip_before_action :set_current_organization
  prepend_before_action :ensure_enabled!
  rate_limit to: 10, within: 3.minutes, only: :link, with: -> { head :too_many_requests }

  def login
    begin_login("login", return_to: HomebaseSettings.safe_path(session[:return_to_after_authenticating]))
  end

  def link
    unless Current.user.authenticate(params[:password].to_s)
      return redirect_to account_security_path, alert: "Confirm your current AI Hub password to link Homebase."
    end
    begin_login("link", user: Current.user, browser_session: Current.session, return_to: account_security_path)
  end

  def callback
    raw = cookies[:ai_hub_homebase_login]
    cookies.delete(:ai_hub_homebase_login, path: "/", secure: request.ssl?)
    transaction = HomebaseLoginTransaction.consume!(raw)
    raise HomebaseIdentityClient::InvalidIdentity unless transaction.issuer == HomebaseSettings.issuer &&
      params[:error].blank? && params[:code].present? && params[:state].is_a?(String) &&
      ActiveSupport::SecurityUtils.secure_compare(params[:state], transaction.state)

    if transaction.purpose == "link"
      resume_session
      raise HomebaseIdentityClient::InvalidIdentity unless Current.user&.id == transaction.user_id && Current.session&.id == transaction.browser_session_id
    end

    tokens, claims = identity.exchange(params[:code], transaction.protocol_data)
    HomebaseAccess.check!(claims.fetch("iss"), claims.fetch("sub"))
    mapping = ExternalIdentity.find_by(issuer: claims.fetch("iss"), subject: claims.fetch("sub"))
    case transaction.purpose
    when "link"
      raise HomebaseIdentityClient::InvalidIdentity if mapping && mapping.user_id != Current.user.id
      Current.user.external_identities.create!(issuer: claims.fetch("iss"), subject: claims.fetch("sub")) unless mapping
      redirect_to account_security_path, notice: "Homebase is linked to your AI Hub account."
    when "login"
      unless mapping
        return redirect_to new_session_path, alert: "Sign in with your existing AI Hub password and link Homebase in Account security first."
      end
      start_new_session_for(mapping.user, homebase: { homebase_issuer: mapping.issuer, homebase_subject: mapping.subject,
        homebase_tokens: tokens.to_json, homebase_expires_at: 8.hours.from_now })
      redirect_to HomebaseSettings.safe_path(transaction.return_to)
    else
      raise HomebaseIdentityClient::InvalidIdentity
    end
  rescue HomebaseAccess::Unavailable
    redirect_to new_session_path, alert: "Homebase is temporarily unavailable. You can still sign in with your AI Hub password."
  rescue StandardError => error
    Rails.logger.warn("Homebase callback rejected: #{error.class.name}")
    redirect_to new_session_path, alert: "Homebase sign-in could not be completed. Please try again."
  end

  private

  def ensure_enabled!
    return head :not_found unless HomebaseSettings.enabled?
    HomebaseSettings.validate!
  end

  def identity = @identity ||= HomebaseIdentityClient.new

  def begin_login(purpose, **options)
    raw, transaction = HomebaseLoginTransaction.issue!(purpose: purpose, **options)
    cookies[:ai_hub_homebase_login] = { value: raw, httponly: true, secure: !HomebaseSettings.local?,
      same_site: :lax, path: "/", expires: 10.minutes.from_now }
    redirect_to identity.authorize(transaction.protocol_data), allow_other_host: true
  rescue StandardError
    raise HomebaseAccess::Unavailable
  end
end
