class JobClaimer
  def initialize(worker)
    @worker = worker
  end

  def claim
    Job.transaction do
      job = Job.claimable.includes(:task_definition).order(priority: :desc, created_at: :asc).limit(50)
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

  def compatible?(definition)
    capabilities = Array(@worker.capabilities)
    capabilities.include?(definition.executor) &&
      definition.requirements.all? { |key, required| !required || capabilities.include?(key.to_s) }
  end
end
