class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    organization = Organization.new(name: @user.organization_name)

    ApplicationRecord.transaction do
      @user.save!
      organization.save!
      organization.memberships.create!(user: @user, role: "owner")
    end
    start_new_session_for(@user)
    session[:organization_id] = organization.id
    redirect_to dashboard_path, notice: "Welcome to AI Hub. Create your first application to get started."
  rescue ActiveRecord::RecordInvalid => e
    @user.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @user
    render :new, status: :unprocessable_entity
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :organization_name)
  end
end
