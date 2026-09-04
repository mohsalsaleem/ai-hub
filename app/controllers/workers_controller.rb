class WorkersController < ApplicationController
  before_action :require_owner!
  before_action :set_worker, only: %i[update destroy rotate_token pause resume]

  def index
    @workers = current_organization.workers.includes(:worker_pools, :worker_enrollment_grants,
      :worker_identity_events).order(last_seen_at: :desc, created_at: :desc)
    @worker = current_organization.workers.new
    @worker_pool = current_organization.worker_pools.new
    @worker_pools = current_organization.worker_pools.order(:name)
  end

  def create
    worker, token = Worker.transaction do
      issued_worker, issued_token = Worker.issue!(organization: current_organization,
        name: worker_params.fetch(:name), trust_tier: worker_params.fetch(:trust_tier, "owner"))
      issued_worker.worker_pools = selected_pools
      [ issued_worker, issued_token ]
    end
    flash[:issued_token] = token
    redirect_to hosting_path(anchor: "issued-token"), notice: "Worker token issued. Copy it now."
  end

  def update
    previous_trust = @worker.trust_tier
    previous_pool_ids = @worker.worker_pool_ids.sort
    @worker.update!(worker_params.except(:worker_pool_ids).to_h.merge(worker_pools: selected_pools))
    @worker.record_identity_event!("trust_changed", from: previous_trust, to: @worker.trust_tier) if previous_trust != @worker.trust_tier
    if previous_pool_ids != @worker.worker_pool_ids.sort
      @worker.record_identity_event!("pools_changed", pool_ids: @worker.worker_pool_ids.sort)
    end
    redirect_to hosting_path(anchor: "worker-#{@worker.id}"), notice: "Worker configuration updated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to hosting_path(anchor: "worker-#{@worker.id}"), alert: e.record.errors.full_messages.to_sentence
  end

  def pause
    @worker.update!(paused_at: Time.current)
    redirect_to hosting_path(anchor: "worker-#{@worker.id}"), notice: "Worker participation paused."
  end

  def resume
    @worker.update!(paused_at: nil)
    redirect_to hosting_path(anchor: "worker-#{@worker.id}"), notice: "Worker participation resumed."
  end

  def rotate_token
    flash[:issued_token] = @worker.rotate_token!
    redirect_to hosting_path(anchor: "issued-token"), notice: "Worker token rotated."
  end

  def destroy
    @worker.update!(active: false)
    @worker.worker_enrollment_grants.active.update_all(revoked_at: Time.current, updated_at: Time.current)
    @worker.record_identity_event!("revoked")
    redirect_to hosting_path, notice: "Worker revoked."
  end

  private

  def set_worker = @worker = current_organization.workers.find(params[:id])
  def worker_params
    params.require(:worker).permit(:name, :trust_tier, :participation_mode, :availability_timezone,
      :availability_starts_at, :availability_ends_at, :max_concurrent_jobs, worker_pool_ids: [], availability_days: [])
  end
  def selected_pools = current_organization.worker_pools.where(id: worker_params.fetch(:worker_pool_ids, []).compact_blank)
end
