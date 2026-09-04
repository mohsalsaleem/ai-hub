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
      organization: @worker.organization_id == job.hub_application.organization_id,
      active: @worker.active?,
      pool: automatic_routing?(job) || @worker.worker_pool_ids.include?(job.worker_pool_id),
      trust: @worker.meets_trust?(job.minimum_worker_trust),
      capabilities: (self.class.required_capabilities(job) - Array(@worker.capabilities)).empty?
    }
  end

  def required_capabilities(job) = self.class.required_capabilities(job)

  private

  def automatic_routing?(job) = job.worker_pool_id.nil? && job.routing_pool_name.nil?
end
