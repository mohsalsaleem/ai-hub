class WorkerPoolsController < ApplicationController
  before_action :require_owner!

  def create
    current_organization.worker_pools.create!(worker_pool_params)
    redirect_to hosting_path, notice: "Worker pool created."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to hosting_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    pool = current_organization.worker_pools.find(params[:id])
    pool.destroy!
    redirect_to hosting_path, notice: "Worker pool removed. Applications using it now allow any eligible worker."
  end

  private

  def worker_pool_params = params.require(:worker_pool).permit(:name)
end
