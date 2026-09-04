class WorkerPool < ApplicationRecord
  belongs_to :organization
  has_many :worker_pool_memberships, dependent: :destroy
  has_many :workers, through: :worker_pool_memberships
  has_many :hub_applications, dependent: :nullify
  has_many :jobs, dependent: :nullify
  has_many :routing_decisions, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: { scope: :organization_id },
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  before_validation :set_slug, on: :create

  private

  def set_slug
    base = name.to_s.parameterize.presence || "pool"
    candidate = base
    candidate = "#{base}-#{SecureRandom.hex(2)}" while organization&.worker_pools&.exists?(slug: candidate)
    self.slug ||= candidate
  end
end
