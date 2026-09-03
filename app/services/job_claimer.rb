class JobClaimer
  def initialize(worker)
    @worker = worker
  end

  def claim
    Job.transaction do
      job = @worker.organization.jobs.where(hub_application_id: eligible_application_ids)
        .merge(Job.claimable).includes(:task_definition)
        .order(priority: :desc, created_at: :asc).limit(50)
        .find { |candidate| compatible?(candidate.task_definition) }
      return unless job

      plaintext = SecureRandom.hex(24)
      job.update!(
        status: "leased", worker: @worker, attempts: job.attempts + 1,
        lease_token_digest: Job.token_digest(plaintext), leased_until: Job::LEASE_SECONDS.seconds.from_now
      )
      [ job, plaintext ]
    end
  end

  private

  def eligible_application_ids
    allowed_trust = Worker::TRUST_TIERS.first(@worker.trust_rank + 1)
    applications = @worker.organization.hub_applications.where(minimum_worker_trust: allowed_trust)
    pool_ids = @worker.worker_pool_ids
    applications.where(worker_pool_id: nil).or(applications.where(worker_pool_id: pool_ids)).select(:id)
  end

  def compatible?(definition)
    capabilities = Array(@worker.capabilities)
    capabilities.include?(definition.executor) &&
      definition.requirements.all? { |key, required| !required || capabilities.include?(key.to_s) }
  end
end
