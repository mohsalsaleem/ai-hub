class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_organization
  helper_method :current_user, :current_organization, :current_membership, :owner?

  private

  def current_user = Current.user
  def current_organization = Current.organization
  def current_membership = @current_membership
  def owner? = current_membership&.owner?

  def set_current_organization
    return unless authenticated?

    memberships = current_user.memberships.includes(:organization)
    @current_membership = memberships.find_by(organization_id: session[:organization_id]) || memberships.first
    Current.organization = @current_membership&.organization
    session[:organization_id] = Current.organization&.id
    redirect_to new_organization_path if Current.organization.nil? && controller_name != "organizations"
  end

  def require_owner!
    redirect_to dashboard_path, alert: "Organization owner access is required." unless owner?
  end
end
