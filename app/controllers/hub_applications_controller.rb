class HubApplicationsController < ApplicationController
  before_action :require_owner!, except: %i[index show task_definitions jobs settings]
  before_action :set_application, only: %i[show task_definitions jobs settings update rotate_token revoke]

  def index
    @applications = current_organization.hub_applications.includes(:jobs, :task_definitions).order(:name)
  end

  def show
    @recent_jobs = application_jobs.limit(5)
  end

  def task_definitions
    @definitions = @application.task_definitions.order(key: :asc, version: :desc)
  end

  def jobs
    @jobs = application_jobs.limit(100)
  end

  def settings
    @worker_pools = current_organization.worker_pools.order(:name)
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
    redirect_to settings_application_path(@application), notice: "Token rotated. The previous token no longer works."
  end

  def update
    if @application.update(routing_params)
      redirect_to settings_application_path(@application), notice: "Worker routing policy updated."
    else
      settings
      render :settings, status: :unprocessable_entity
    end
  end

  def revoke
    @application.update!(active: false)
    redirect_to applications_path, notice: "Application revoked."
  end

  private

  def set_application = @application = current_organization.hub_applications.find(params[:id])
  def application_jobs = @application.jobs.includes(:task_definition, :worker).order(created_at: :desc)
  def application_params = params.require(:hub_application).permit(:name, :slug)
  def routing_params = params.require(:hub_application).permit(:minimum_worker_trust, :worker_pool_id)
end
