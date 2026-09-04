class WorkerEligibility
  def self.required_capabilities(job)
    [ job.task_definition.executor ] +
      job.task_definition.requirements.filter_map { |key, required| key.to_s if required }
  end

  def initialize(worker)
    @worker = worker
  end

  def eligible_for?(job) = checks(job).values.all?

  def checks(job)
    {
      pool_access: local_run?(job) || shared_pool_access?(job),
      active: @worker.active?,
      pool: automatic_routing?(job) || @worker.worker_pool_ids.include?(job.worker_pool_id),
      participation: local_run?(job) || @worker.participation_mode == "shared",
      trust: trust_requirement_met?(job),
      capabilities: (self.class.required_capabilities(job) - Array(@worker.capabilities)).empty?
    }
  end

  def required_capabilities(job) = self.class.required_capabilities(job)

  private

  def automatic_routing?(job) = job.worker_pool_id.nil? && job.routing_pool_name.nil?

  def local_run?(job) = @worker.organization_id == job.hub_application.organization_id

  def shared_pool_access?(job)
    pool = job.worker_pool
    pool&.organization_id == @worker.organization_id && pool.shared? &&
      pool.worker_pool_access_grants.exists?(organization_id: job.hub_application.organization_id)
  end

  def trust_requirement_met?(job)
    return @worker.meets_trust?(job.minimum_worker_trust) if local_run?(job)

    case job.minimum_worker_trust
    when "external" then true
    when "verified" then @worker.trust_tier == "verified"
    else false
    end
  end
end
