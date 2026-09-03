class WorkerPoolMembership < ApplicationRecord
  belongs_to :worker_pool
  belongs_to :worker

  validates :worker_id, uniqueness: { scope: :worker_pool_id }
  validate :same_organization

  private

  def same_organization
    return if worker.nil? || worker_pool.nil? || worker.organization_id == worker_pool.organization_id

    errors.add(:worker, "must belong to the pool organization")
  end
end
