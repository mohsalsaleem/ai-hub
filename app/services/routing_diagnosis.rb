class RoutingDiagnosis
  Diagnosis = Data.define(:code, :summary)

  def initialize(job)
    @job = job
  end

  def call
    return selected_diagnosis if @job.worker_id.present? || @job.routing_decisions.selected.exists?

    workers = candidate_workers
    workers = workers.select { |worker| pool_match?(worker) }
    return diagnosis("no_capacity", "No provider capacity is registered for this routing target.") if workers.empty?

    workers = workers.select(&:active?)
    return diagnosis("capacity_inactive", "Capacity is registered in this pool but is not accepting runs.") if workers.empty?

    workers = workers.select { |worker| WorkerEligibility.new(worker).checks(@job).fetch(:trust) }
    return diagnosis("trust_requirement_not_met", "Available capacity does not meet this application's trust requirement.") if workers.empty?

    workers = workers.select { |worker| WorkerEligibility.new(worker).eligible_for?(@job) }
    return diagnosis("capabilities_unavailable", "This pool does not currently offer the capabilities required by the task.") if workers.empty?

    available_workers = workers.reject(&:paused?)
    return diagnosis("capacity_paused", "Compatible capacity is manually paused.") if available_workers.empty?

    available_workers = available_workers.select { |worker| worker.scheduled_available_at? }
    return diagnosis("scheduled_offline", "Compatible capacity is outside its configured availability schedule.") if available_workers.empty?
    return diagnosis("eligible_capacity_offline", "Compatible capacity exists but is not currently online.") unless available_workers.any?(&:online?)

    available_workers = available_workers.select do |worker|
      worker.active_lease_count < worker.max_concurrent_jobs
    end
    return diagnosis("capacity_busy", "Compatible capacity is currently at its concurrency limit.") if available_workers.empty?

    diagnosis("awaiting_claim", "Compatible capacity is available and the run is awaiting a claim.")
  end

  private

  def selected_diagnosis
    diagnosis("capacity_selected", "Compatible capacity was selected from the configured pool.")
  end

  def pool_match?(worker)
    automatic_routing? || worker.worker_pool_ids.include?(@job.worker_pool_id)
  end

  def automatic_routing? = @job.worker_pool_id.nil? && @job.routing_pool_name.nil?

  def candidate_workers
    return [] if @job.worker_pool_id.nil? && @job.routing_pool_name.present?

    scope = @job.worker_pool ? @job.worker_pool.workers : @job.hub_application.organization.workers
    scope.includes(:worker_pools).to_a
  end

  def diagnosis(code, summary) = Diagnosis.new(code:, summary:)
end
