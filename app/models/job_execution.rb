class JobExecution < ApplicationRecord
  OUTCOMES = %w[running completed failed dead expired].freeze

  belongs_to :job
  belongs_to :worker, optional: true
  belongs_to :worker_pool, optional: true
  belongs_to :consumer_organization, class_name: "Organization", inverse_of: :consumed_job_executions
  belongs_to :provider_organization, class_name: "Organization", inverse_of: :provided_job_executions

  validates :attempt_number, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :job_id }
  validates :outcome, inclusion: { in: OUTCOMES }
  validates :consumer_organization_name, :provider_organization_name, :application_name,
    :task_reference, :worker_name, :started_at, presence: true
  validates :input_tokens, :output_tokens, :total_tokens,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :model_duration_ms, :hub_duration_ms,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :token_total_is_consistent

  before_update :prevent_finalized_changes
  before_destroy :prevent_destruction

  scope :finalized, -> { where.not(finished_at: nil) }
  scope :shared, -> { where(shared: true) }

  def self.start_for!(job:, worker:, started_at: Time.current)
    application = job.hub_application
    consumer = application.organization
    provider = worker.organization
    create!(job:, attempt_number: job.attempts, worker:, worker_pool: job.worker_pool,
      consumer_organization: consumer, provider_organization: provider,
      consumer_organization_name: consumer.name, provider_organization_name: provider.name,
      application_name: application.name, task_reference: job.task_definition.reference,
      worker_name: worker.name, worker_pool_name: job.routing_pool_name,
      shared: consumer != provider, started_at:, outcome: "running")
  end

  def finalized? = finished_at.present?

  def finalize!(outcome:, usage: UsageReport.normalize(nil), failure_code: nil, finished_at: Time.current)
    raise ActiveRecord::RecordNotSaved, "Execution is already finalized" if finalized?

    update!(usage.merge(outcome:, failure_code: failure_code.to_s.first(100).presence, finished_at:,
      hub_duration_ms: [ ((finished_at - started_at) * 1000).round, 0 ].max))
  end

  private

  def token_total_is_consistent
    return unless input_tokens && output_tokens && total_tokens
    return if total_tokens == input_tokens + output_tokens

    errors.add(:total_tokens, "must equal input and output tokens")
  end

  def prevent_finalized_changes
    return unless finished_at_in_database.present?

    errors.add(:base, "Finalized executions are immutable")
    throw :abort
  end

  def prevent_destruction
    errors.add(:base, "Execution records are immutable")
    throw :abort
  end
end
