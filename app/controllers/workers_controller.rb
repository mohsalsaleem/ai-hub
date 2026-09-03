class WorkersController < ApplicationController
  before_action :require_owner!, except: :index
  before_action :set_worker, only: %i[destroy rotate_token]

  def index
    @workers = current_organization.workers.order(last_seen_at: :desc, created_at: :desc)
    @worker = current_organization.workers.new
  end

  def create
    worker, token = Worker.issue!(organization: current_organization, name: params.require(:worker).fetch(:name))
    flash[:issued_token] = token
    redirect_to workers_path(anchor: "issued-token"), notice: "Worker token issued. Copy it now."
  end

  def rotate_token
    flash[:issued_token] = @worker.rotate_token!
    redirect_to workers_path(anchor: "issued-token"), notice: "Worker token rotated."
  end

  def destroy
    @worker.update!(active: false)
    redirect_to workers_path, notice: "Worker revoked."
  end

  private

  def set_worker = @worker = current_organization.workers.find(params[:id])
end
