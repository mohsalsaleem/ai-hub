class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :hub_applications, dependent: :destroy
  has_many :workers, dependent: :destroy
  has_many :worker_pools, dependent: :destroy
  has_many :worker_pool_access_grants, dependent: :destroy
  has_many :accessible_worker_pools, through: :worker_pool_access_grants, source: :worker_pool
  has_many :task_definitions, through: :hub_applications
  has_many :jobs, through: :hub_applications
  has_many :consumed_job_executions, class_name: "JobExecution",
    foreign_key: :consumer_organization_id, inverse_of: :consumer_organization, dependent: :restrict_with_error
  has_many :provided_job_executions, class_name: "JobExecution",
    foreign_key: :provider_organization_id, inverse_of: :provider_organization, dependent: :restrict_with_error
  has_many :credit_ledger_entries, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  before_validation :set_slug, on: :create

  private

  def set_slug
    base = name.to_s.parameterize.presence || "organization"
    candidate = base
    candidate = "#{base}-#{SecureRandom.hex(2)}" while Organization.exists?(slug: candidate)
    self.slug ||= candidate
  end
end
