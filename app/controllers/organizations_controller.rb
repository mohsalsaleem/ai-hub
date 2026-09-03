class OrganizationsController < ApplicationController
  before_action :require_owner!, only: :update

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)
    @organization.transaction do
      @organization.save!
      @organization.memberships.create!(user: current_user, role: "owner")
    end
    session[:organization_id] = @organization.id
    redirect_to root_path, notice: "Organization created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @memberships = current_organization.memberships.includes(:user).order(:created_at)
  end

  def update
    if current_organization.update(organization_params)
      redirect_to organization_path, notice: "Organization updated."
    else
      show
      render :show, status: :unprocessable_entity
    end
  end

  private

  def organization_params = params.require(:organization).permit(:name)
end
