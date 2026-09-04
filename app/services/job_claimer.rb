class JobClaimer
  def initialize(worker)
    @worker = worker
  end

  def claim
    Job.transaction do
      expire_exhausted_leases
      return unless @worker.accepting_jobs?

      job = eligible_jobs
        .merge(Job.claimable).includes(:task_definition)
        .order(priority: :desc, created_at: :asc).limit(50)
        .find { |candidate| eligibility.eligible_for?(candidate) }
      return unless job

      plaintext = SecureRandom.hex(24)
      job.update!(
        status: "leased", worker: @worker, attempts: job.attempts + 1,
        lease_token_digest: Job.token_digest(plaintext), leased_until: Job::LEASE_SECONDS.seconds.from_now
      )
      job.routing_decisions.create!(outcome: "selected", reason: "eligible_worker_selected",
        worker: @worker, worker_pool: job.worker_pool,
        evidence: { attempt: job.attempts, worker: { id: @worker.id, name: @worker.name },
                    routing_pool: { id: job.worker_pool_id, name: job.routing_pool_name },
                    provider_policy: { participation_mode: @worker.participation_mode,
                                       max_concurrent_jobs: @worker.max_concurrent_jobs },
                    checks: eligibility.checks(job),
                    required_capabilities: eligibility.required_capabilities(job) })
      [ job, plaintext ]
    end
  end

  private

  def expire_exhausted_leases
    now = Time.current
    @worker.jobs.where(status: "leased").where("jobs.leased_until < ?", now)
      .where("jobs.attempts >= jobs.max_attempts")
      .update_all(status: "dead", completed_at: now, leased_until: nil, lease_token_digest: nil,
                  error: { code: "lease_expired", message: "The worker lease expired after the final attempt." },
                  updated_at: now)
  end

  def eligible_jobs
    allowed_trust = Worker::TRUST_TIERS.first(@worker.trust_rank + 1)
    jobs = Job.where(minimum_worker_trust: allowed_trust)
    pool_ids = @worker.worker_pool_ids
    local_application_ids = @worker.organization.hub_applications.select(:id)
    local_jobs = jobs.where(hub_application_id: local_application_ids)
    local_ids = local_jobs.where(worker_pool_id: nil, routing_pool_name: nil)
      .or(local_jobs.where(worker_pool_id: pool_ids)).select(:id)
    return jobs.where(id: local_ids) unless @worker.participation_mode == "shared"

    shared_pool_ids = @worker.worker_pools.where(access_mode: "shared").select(:id)
    shared_ids = jobs.joins(:hub_application)
      .joins("INNER JOIN worker_pool_access_grants ON worker_pool_access_grants.worker_pool_id = jobs.worker_pool_id")
      .where(worker_pool_id: shared_pool_ids)
      .where("worker_pool_access_grants.organization_id = hub_applications.organization_id")
      .select(:id)
    jobs.where(id: local_ids).or(jobs.where(id: shared_ids))
  end

  def eligibility = @eligibility ||= WorkerEligibility.new(@worker)
end
