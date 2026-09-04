class Job < ApplicationRecord
  STATUSES = %w[queued leased completed failed dead].freeze
  LEASE_SECONDS = 180

  belongs_to :hub_application
  belongs_to :task_definition
  belongs_to :worker, optional: true
  belongs_to :worker_pool, optional: true
  has_many :routing_decisions, dependent: :destroy
  has_many :job_executions, dependent: :restrict_with_error

  validates :public_id, presence: true, uniqueness: true
  validates :idempotency_key, presence: true, uniqueness: { scope: :hub_application_id }
  validates :status, inclusion: { in: STATUSES }
  validates :max_attempts, numericality: { only_integer: true, in: 1..10 }
  validates :minimum_worker_trust, inclusion: { in: Worker::TRUST_TIERS }
  validate :input_matches_definition, on: :create
  validate :routing_pool_matches_application, on: :create

  before_validation :set_defaults, on: :create
  after_create :record_initial_routing_decision

  scope :claimable, -> {
    where("(jobs.status = 'queued' AND jobs.available_at <= ?) OR (jobs.status = 'leased' AND jobs.leased_until < ?)",
      Time.current, Time.current).where("jobs.attempts < jobs.max_attempts")
  }

  def lease_valid?(plaintext)
    leased? && leased_until&.future? && lease_token_digest.present? &&
      ActiveSupport::SecurityUtils.secure_compare(lease_token_digest, self.class.token_digest(plaintext))
  end

  def leased? = status == "leased"

  def self.token_digest(value) = OpenSSL::Digest::SHA256.hexdigest(value.to_s)

  private

  def set_defaults
    self.public_id ||= "job_#{SecureRandom.hex(12)}"
    self.available_at ||= Time.current
    self.worker_pool = hub_application&.worker_pool
    self.routing_pool_name = worker_pool&.name
    self.minimum_worker_trust = hub_application&.minimum_worker_trust
  end

  def record_initial_routing_decision
    routing_decisions.create!(outcome: "queued", reason: "awaiting_eligible_capacity", worker_pool:,
      evidence: { minimum_worker_trust:, routing_pool: { id: worker_pool_id, name: routing_pool_name },
                  required_capabilities: WorkerEligibility.required_capabilities(self) })
  end

  def input_matches_definition
    return unless task_definition && input

    errors.add(:input, "does not match task schema") unless JSONSchemer.schema(task_definition.input_schema).valid?(input)
  end

  def routing_pool_matches_application
    return if worker_pool.nil? || worker_pool.routing_authorized_for?(hub_application&.organization)

    errors.add(:worker_pool, "is not available to the application organization")
  end
end
