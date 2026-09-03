class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :hub_applications, dependent: :destroy
  has_many :workers, dependent: :destroy
  has_many :task_definitions, through: :hub_applications
  has_many :jobs, through: :hub_applications

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
