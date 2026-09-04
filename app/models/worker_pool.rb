class WorkerPool < ApplicationRecord
  ACCESS_MODES = %w[private shared].freeze
  OPERATOR_STATUSES = %w[not_applicable pending_review approved suspended revoked].freeze
  OPERATOR_TRANSITIONS = {
    "pending_review" => %w[approved revoked],
    "approved" => %w[suspended revoked],
    "suspended" => %w[approved revoked],
    "revoked" => []
  }.freeze

  belongs_to :organization
  has_many :worker_pool_memberships, dependent: :destroy
  has_many :workers, through: :worker_pool_memberships
  has_many :hub_applications, dependent: :nullify
  has_many :jobs, dependent: :nullify
  has_many :routing_decisions, dependent: :nullify
  has_many :worker_pool_access_grants, dependent: :destroy
  has_many :consumer_organizations, through: :worker_pool_access_grants, source: :organization

  validates :name, presence: true, length: { maximum: 100 }
  validates :access_mode, inclusion: { in: ACCESS_MODES }
  validates :operator_status, inclusion: { in: OPERATOR_STATUSES }
  validates :slug, presence: true, uniqueness: { scope: :organization_id },
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validate :operator_status_matches_access_mode

  before_validation :normalize_operator_status
  before_validation :set_slug, on: :create

  scope :accessible_to, ->(organization) {
    owned = where(organization:)
    granted_ids = WorkerPoolAccessGrant.where(organization:).select(:worker_pool_id)
    owned.or(where(access_mode: "shared", operator_status: "approved", id: granted_ids))
  }
  scope :shared, -> { where(access_mode: "shared") }

  def shared? = access_mode == "shared"
  def shared_access_enabled? = shared? && operator_status == "approved"

  def granted_to?(consumer)
    shared? && worker_pool_access_grants.exists?(organization: consumer)
  end

  def routing_authorized_for?(consumer)
    organization_id == consumer&.id || granted_to?(consumer)
  end

  def accessible_to?(consumer)
    organization_id == consumer&.id ||
      (shared_access_enabled? && granted_to?(consumer))
  end

  def transition_operator_status!(target)
    target = target.to_s
    unless OPERATOR_TRANSITIONS.fetch(operator_status, []).include?(target)
      raise ArgumentError, "Cannot transition shared pool from #{operator_status} to #{target}"
    end

    update!(operator_status: target)
  end

  def revoke_shared_access!
    transaction do
      worker_pool_access_grants.each(&:destroy!)
      transition_operator_status!("revoked")
    end
  end

  private

  def normalize_operator_status
    if access_mode == "private"
      self.operator_status = "not_applicable"
    elsif operator_status.blank? || operator_status == "not_applicable"
      self.operator_status = "pending_review"
    end
  end

  def operator_status_matches_access_mode
    if shared? && operator_status == "not_applicable"
      errors.add(:operator_status, "must be reviewed for a shared pool")
    elsif !shared? && operator_status != "not_applicable"
      errors.add(:operator_status, "is only available for shared pools")
    end
  end

  def set_slug
    base = name.to_s.parameterize.presence || "pool"
    candidate = base
    candidate = "#{base}-#{SecureRandom.hex(2)}" while organization&.worker_pools&.exists?(slug: candidate)
    self.slug ||= candidate
  end
end
