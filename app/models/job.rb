class Job < ApplicationRecord
  STATUSES = %w[queued leased completed failed dead].freeze
  LEASE_SECONDS = 180

  belongs_to :hub_application
  belongs_to :task_definition
  belongs_to :worker, optional: true

  validates :public_id, presence: true, uniqueness: true
  validates :idempotency_key, presence: true, uniqueness: { scope: :hub_application_id }
  validates :status, inclusion: { in: STATUSES }
  validates :max_attempts, numericality: { only_integer: true, in: 1..10 }
  validate :input_matches_definition, on: :create

  before_validation :set_defaults, on: :create

  scope :claimable, -> {
    where("(status = 'queued' AND available_at <= ?) OR (status = 'leased' AND leased_until < ?)", Time.current, Time.current)
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
  end

  def input_matches_definition
    return unless task_definition && input

    errors.add(:input, "does not match task schema") unless JSONSchemer.schema(task_definition.input_schema).valid?(input)
  end
end
