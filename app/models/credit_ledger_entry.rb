class CreditLedgerEntry < ApplicationRecord
  ENTRY_TYPES = %w[consumer_debit provider_credit platform_credit].freeze

  belongs_to :job_execution
  belongs_to :organization, optional: true

  validates :entry_type, inclusion: { in: ENTRY_TYPES }, uniqueness: { scope: :job_execution_id }
  validates :amount, numericality: { only_integer: true }
  validates :unit, inclusion: { in: %w[internal_credit] }
  validates :pricing_version, numericality: { only_integer: true, greater_than: 0 }
  validate :account_matches_entry_type
  validate :amount_matches_entry_type

  before_update :prevent_changes
  before_destroy :prevent_changes

  private

  def account_matches_entry_type
    if entry_type == "platform_credit"
      errors.add(:organization, "must be absent for the platform account") if organization_id.present?
    elsif organization_id.blank?
      errors.add(:organization, "must be present")
    end
  end

  def amount_matches_entry_type
    return if amount.nil?

    if entry_type == "consumer_debit"
      errors.add(:amount, "must be negative") unless amount.negative?
    elsif !amount.positive? && !(entry_type == "platform_credit" && amount.zero?)
      errors.add(:amount, "must be positive")
    end
  end

  def prevent_changes
    errors.add(:base, "Credit ledger entries are immutable")
    throw :abort
  end
end
