class HubApplicationsController < ApplicationController
  before_action :require_owner!, except: %i[index show]
  before_action :set_application, only: %i[show rotate_token revoke]

  def index
    @applications = current_organization.hub_applications.includes(:jobs, :task_definitions).order(:name)
  end

  def show
    @definitions = @application.task_definitions.order(key: :asc, version: :desc)
    @jobs = @application.jobs.includes(:task_definition, :worker).order(created_at: :desc).limit(20)
  end

  def new
    @application = current_organization.hub_applications.new
  end

  def create
    @application, token = HubApplication.issue!(**application_params.to_h.symbolize_keys,
      organization: current_organization)
    flash[:issued_token] = token
    redirect_to application_path(@application), notice: "Application created. Copy its token now."
  rescue ActiveRecord::RecordInvalid => e
    @application = e.record
    render :new, status: :unprocessable_entity
  end

  def rotate_token
    flash[:issued_token] = @application.rotate_token!
    redirect_to application_path(@application), notice: "Token rotated. The previous token no longer works."
  end

  def revoke
    @application.update!(active: false)
    redirect_to applications_path, notice: "Application revoked."
  end

  private

  def set_application = @application = current_organization.hub_applications.find(params[:id])
  def application_params = params.require(:hub_application).permit(:name, :slug)
end
