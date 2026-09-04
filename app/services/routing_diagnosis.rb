class RoutingDiagnosis
  Diagnosis = Data.define(:code, :summary)

  def initialize(job)
    @job = job
  end

  def call
    return selected_diagnosis if @job.worker_id.present? || @job.routing_decisions.selected.exists?

    workers = @job.hub_application.organization.workers.includes(:worker_pools).to_a
    workers = workers.select { |worker| pool_match?(worker) }
    return diagnosis("no_capacity", "No provider capacity is registered for this routing target.") if workers.empty?

    workers = workers.select(&:active?)
    return diagnosis("capacity_inactive", "Capacity is registered in this pool but is not accepting runs.") if workers.empty?

    workers = workers.select { |worker| worker.meets_trust?(@job.minimum_worker_trust) }
    return diagnosis("trust_requirement_not_met", "Available capacity does not meet this application's trust requirement.") if workers.empty?

    workers = workers.select { |worker| WorkerEligibility.new(worker).eligible_for?(@job) }
    return diagnosis("capabilities_unavailable", "This pool does not currently offer the capabilities required by the task.") if workers.empty?
    return diagnosis("eligible_capacity_offline", "Compatible capacity exists but is not currently online.") unless workers.any?(&:online?)

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

  def diagnosis(code, summary) = Diagnosis.new(code:, summary:)
end
