module Platform
  class WorkerPoolsController < BaseController
    before_action :set_worker_pool

    def approve
      transition_to!("approved", "shared_pool.approved", "Shared pool approved.")
    end

    def suspend
      transition_to!("suspended", "shared_pool.suspended", "Shared pool suspended.")
    end

    def revoke
      previous_status = @worker_pool.operator_status
      grant_count = @worker_pool.worker_pool_access_grants.count

      WorkerPool.transaction do
        @worker_pool.revoke_shared_access!
        record_audit!("shared_pool.revoked", previous_status:, grant_count:)
      end

      redirect_to platform_root_path, notice: "Shared pool access revoked."
    rescue ArgumentError => e
      redirect_to platform_root_path, alert: e.message
    end

    private

    def set_worker_pool
      @worker_pool = WorkerPool.shared.find(params[:id])
    end

    def transition_to!(status, action, notice)
      previous_status = @worker_pool.operator_status
      WorkerPool.transaction do
        @worker_pool.transition_operator_status!(status)
        record_audit!(action, previous_status:)
      end
      redirect_to platform_root_path(anchor: "pool-#{@worker_pool.id}"), notice:
    rescue ArgumentError => e
      redirect_to platform_root_path(anchor: "pool-#{@worker_pool.id}"), alert: e.message
    end

    def record_audit!(action, **details)
      current_platform_operator.platform_audit_events.create!(action:, subject_type: "WorkerPool",
        subject_id: @worker_pool.id, subject_label: @worker_pool.name,
        request_ip: request.remote_ip,
        details: details.merge(provider_organization_id: @worker_pool.organization_id,
          consumer_grants: @worker_pool.worker_pool_access_grants.count,
          workers: @worker_pool.workers.count))
    end
  end
end
