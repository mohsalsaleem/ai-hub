class HubApplication < ApplicationRecord
  include TokenAuthenticatable

  belongs_to :organization
  belongs_to :worker_pool, optional: true
  has_many :task_definitions, dependent: :destroy
  has_many :jobs, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :organization_id },
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :minimum_worker_trust, inclusion: { in: Worker::TRUST_TIERS }
  validate :worker_pool_matches_organization

  private

  def worker_pool_matches_organization
    return if worker_pool.nil? || worker_pool.accessible_to?(organization)

    errors.add(:worker_pool, "is not available to this organization")
  end
end
