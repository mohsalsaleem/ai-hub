class JobClaimer
  def initialize(worker)
    @worker = worker
  end

  def claim
    Job.transaction do
      expire_exhausted_leases
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
                    checks: eligibility.checks(job),
                    required_capabilities: eligibility.required_capabilities(job) })
      [ job, plaintext ]
    end
  end

  private

  def expire_exhausted_leases
    now = Time.current
    @worker.organization.jobs.where(status: "leased").where("jobs.leased_until < ?", now)
      .where("jobs.attempts >= jobs.max_attempts")
      .update_all(status: "dead", completed_at: now, leased_until: nil, lease_token_digest: nil,
                  error: { code: "lease_expired", message: "The worker lease expired after the final attempt." },
                  updated_at: now)
  end

  def eligible_jobs
    allowed_trust = Worker::TRUST_TIERS.first(@worker.trust_rank + 1)
    jobs = @worker.organization.jobs.where(minimum_worker_trust: allowed_trust)
    pool_ids = @worker.worker_pool_ids
    jobs.where(worker_pool_id: nil, routing_pool_name: nil).or(jobs.where(worker_pool_id: pool_ids))
  end

  def eligibility = @eligibility ||= WorkerEligibility.new(@worker)
end
