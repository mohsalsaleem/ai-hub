class CreditLedgerEntry < ApplicationRecord
  EXECUTION_ENTRY_TYPES = %w[consumer_debit provider_credit platform_credit].freeze
  ENTRY_TYPES = (EXECUTION_ENTRY_TYPES + %w[admin_adjustment]).freeze

  belongs_to :job_execution, optional: true
  belongs_to :organization, optional: true
  belongs_to :platform_operator, optional: true

  validates :entry_type, inclusion: { in: ENTRY_TYPES }, uniqueness: { scope: :job_execution_id }
  validates :amount, numericality: { only_integer: true }
  validates :unit, inclusion: { in: %w[internal_credit] }
  validates :pricing_version, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, presence: true, length: { maximum: 500 }, if: :admin_adjustment?
  validate :account_matches_entry_type
  validate :amount_matches_entry_type

  before_update :prevent_changes
  before_destroy :prevent_changes

  private

  def account_matches_entry_type
    if admin_adjustment?
      errors.add(:organization, "must be present") if organization_id.blank?
      errors.add(:platform_operator, "must be present") if platform_operator_id.blank?
      errors.add(:job_execution, "must be absent") if job_execution_id.present?
    elsif entry_type == "platform_credit"
      errors.add(:organization, "must be absent for the platform account") if organization_id.present?
    else
      errors.add(:organization, "must be present") if organization_id.blank?
    end
    errors.add(:job_execution, "must be present") if entry_type.in?(EXECUTION_ENTRY_TYPES) && job_execution_id.blank?
  end

  def amount_matches_entry_type
    return if amount.nil?

    if entry_type == "consumer_debit"
      errors.add(:amount, "must be negative") unless amount.negative?
    elsif entry_type != "admin_adjustment" && !amount.positive? && !(entry_type == "platform_credit" && amount.zero?)
      errors.add(:amount, "must be positive")
    end
  end

  def admin_adjustment? = entry_type == "admin_adjustment"

  def prevent_changes
    errors.add(:base, "Credit ledger entries are immutable")
    throw :abort
  end
end
