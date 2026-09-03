class Worker < ApplicationRecord
  include TokenAuthenticatable

  TRUST_TIERS = %w[external verified organization owner].freeze

  belongs_to :organization
  has_many :jobs, dependent: :nullify
  has_many :worker_request_nonces, dependent: :delete_all
  has_many :worker_pool_memberships, dependent: :destroy
  has_many :worker_pools, through: :worker_pool_memberships

  validates :name, presence: true
  validates :trust_tier, inclusion: { in: TRUST_TIERS }

  def trust_rank = TRUST_TIERS.index(trust_tier)

  def meets_trust?(minimum)
    trust_rank >= TRUST_TIERS.index(minimum.to_s)
  end

  def enrolled? = public_key_pem.present? && key_fingerprint.present?

  def rotate_token!
    transaction do
      plaintext = super
      update!(public_key_pem: nil, key_fingerprint: nil, enrolled_at: nil,
        identity_rotated_at: Time.current)
      worker_request_nonces.delete_all
      plaintext
    end
  end

  def seen!(reported_id:, version:, capabilities:)
    update_columns(
      reported_id: reported_id.to_s.first(100).presence,
      version: version.to_s.first(60).presence,
      capabilities: Array(capabilities).map { |value| value.to_s.first(100) }.uniq.first(50),
      last_seen_at: Time.current
    )
  end

  def online? = last_seen_at.present? && last_seen_at > 2.minutes.ago
end
