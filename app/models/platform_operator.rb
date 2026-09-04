class PlatformOperator < ApplicationRecord
  has_secure_password

  has_many :platform_sessions, dependent: :destroy
  has_many :platform_audit_events, dependent: :restrict_with_error

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 12 }, allow_nil: true
end
