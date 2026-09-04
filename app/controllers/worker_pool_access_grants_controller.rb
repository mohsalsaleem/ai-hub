class WorkerPoolAccessGrantsController < ApplicationController
  before_action :require_owner!
  before_action :set_worker_pool

  def create
    consumer = Organization.find_by!(slug: grant_params.fetch(:organization_slug))
    @worker_pool.worker_pool_access_grants.create!(organization: consumer)
    redirect_to hosting_path(anchor: "pool-#{@worker_pool.id}"), notice: "Consumer access granted."
  rescue ActiveRecord::RecordNotFound
    redirect_to hosting_path(anchor: "pool-#{@worker_pool.id}"), alert: "Organization not found."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to hosting_path(anchor: "pool-#{@worker_pool.id}"), alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    @worker_pool.worker_pool_access_grants.find(params[:id]).destroy!
    redirect_to hosting_path(anchor: "pool-#{@worker_pool.id}"), notice: "Consumer access revoked."
  end

  private

  def set_worker_pool = @worker_pool = current_organization.worker_pools.find(params[:worker_pool_id])
  def grant_params = params.require(:worker_pool_access_grant).permit(:organization_slug)
end
