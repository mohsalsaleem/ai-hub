class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_operator

  private

  def authenticate_operator
    password = ENV["AI_HUB_ADMIN_PASSWORD"]
    return if password.blank? && !Rails.env.production?

    authenticate_or_request_with_http_basic("AI Hub") do |_username, supplied|
      password.present? && ActiveSupport::SecurityUtils.secure_compare(password, supplied.to_s)
    end
  end
end
