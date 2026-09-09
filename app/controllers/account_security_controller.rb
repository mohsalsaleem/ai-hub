class AccountSecurityController < ApplicationController
  skip_before_action :set_current_organization

  def show
    # Personal identity settings remain accessible without an organization.
    set_current_organization if current_user.memberships.exists?
  end
end
