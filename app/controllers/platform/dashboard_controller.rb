module Platform
  class DashboardController < BaseController
    def show
      @organizations = Organization.includes(:hub_applications, :workers).order(:name)
      @shared_pools = WorkerPool.shared.includes(:organization, :workers,
        worker_pool_access_grants: :organization).order(created_at: :desc)
      @shared_workers = Worker.where(participation_mode: "shared")
      @recent_shared_runs = Job.joins(:hub_application, :worker_pool)
        .where("hub_applications.organization_id != worker_pools.organization_id")
        .includes(:job_executions, :hub_application, worker_pool: :organization)
        .order(created_at: :desc).limit(20)
      shared_usage = JobExecution.shared.finalized.where(finished_at: 30.days.ago..Time.current)
      @shared_usage_summary = UsageSummary.new(shared_usage).call
      @audit_events = PlatformAuditEvent.includes(:platform_operator).order(created_at: :desc).limit(20)
      @ledger_reconciliation = LedgerReconciliation.call
      @platform_credits = CreditLedgerEntry.where(entry_type: "platform_credit").sum(:amount)
    end
  end
end
