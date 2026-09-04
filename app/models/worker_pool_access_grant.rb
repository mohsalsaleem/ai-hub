class WorkerPoolAccessGrant < ApplicationRecord
  belongs_to :worker_pool
  belongs_to :organization

  validates :organization_id, uniqueness: { scope: :worker_pool_id }
  validate :shared_pool
  validate :different_organization

  after_destroy :clear_application_routing

  private

  def shared_pool
    errors.add(:worker_pool, "must be shared") unless worker_pool&.shared?
  end

  def different_organization
    return if worker_pool.nil? || organization_id != worker_pool.organization_id

    errors.add(:organization, "already owns this pool")
  end

  def clear_application_routing
    organization.hub_applications.where(worker_pool:).update_all(worker_pool_id: nil, updated_at: Time.current)
  end
end
