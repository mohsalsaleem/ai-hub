class WorkerPool < ApplicationRecord
  ACCESS_MODES = %w[private shared].freeze

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
  validates :slug, presence: true, uniqueness: { scope: :organization_id },
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  before_validation :set_slug, on: :create

  scope :accessible_to, ->(organization) {
    owned = where(organization:)
    granted_ids = WorkerPoolAccessGrant.where(organization:).select(:worker_pool_id)
    owned.or(where(access_mode: "shared", id: granted_ids))
  }

  def shared? = access_mode == "shared"

  def accessible_to?(consumer)
    organization_id == consumer&.id ||
      (shared? && worker_pool_access_grants.exists?(organization: consumer))
  end

  private

  def set_slug
    base = name.to_s.parameterize.presence || "pool"
    candidate = base
    candidate = "#{base}-#{SecureRandom.hex(2)}" while organization&.worker_pools&.exists?(slug: candidate)
    self.slug ||= candidate
  end
end
