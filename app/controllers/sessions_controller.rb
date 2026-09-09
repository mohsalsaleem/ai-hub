class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  allow_unauthenticated_access only: :destroy
  skip_before_action :set_current_organization
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      destination = after_authentication_url
      start_new_session_for user
      redirect_to destination
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    record = Session.find_by(id: cookies.signed[:session_id])
    logout_url = nil
    logout_unavailable = false
    begin
      logout_url = HomebaseIdentityClient.new.logout_url(JSON.parse(record.homebase_tokens)) if record&.homebase? && HomebaseSettings.enabled?
    rescue StandardError
      logout_unavailable = true
    ensure
      Current.session = record
      terminate_session
    end
    flash[:alert] = "Signed out of AI Hub. Homebase sign-out was unavailable." if logout_unavailable
    redirect_to logout_url || new_session_path, allow_other_host: logout_url.present?, status: :see_other
  end
  private

  # Password sign-in remains usable even when an old Homebase session cannot
  # be verified. This does not resume that session or grant any account access.
  def resume_session
    return nil if %w[new create].include?(action_name)
    super
  end
end
