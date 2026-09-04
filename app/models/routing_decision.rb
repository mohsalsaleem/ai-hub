class RoutingDecision < ApplicationRecord
  OUTCOMES = %w[queued selected].freeze
  MAX_EVIDENCE_BYTES = 4.kilobytes

  belongs_to :job
  belongs_to :worker_pool, optional: true
  belongs_to :worker, optional: true

  validates :outcome, inclusion: { in: OUTCOMES }
  validates :reason, presence: true
  validate :evidence_is_bounded

  scope :selected, -> { where(outcome: "selected") }

  private

  def evidence_is_bounded
    errors.add(:evidence, "is too large") if JSON.generate(evidence).bytesize > MAX_EVIDENCE_BYTES
  end
end
