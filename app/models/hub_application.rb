class HubApplication < ApplicationRecord
  include TokenAuthenticatable

  has_many :task_definitions, dependent: :destroy
  has_many :jobs, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
end
