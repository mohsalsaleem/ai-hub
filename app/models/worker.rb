class Worker < ApplicationRecord
  include TokenAuthenticatable

  TRUST_TIERS = %w[external verified organization owner].freeze

  belongs_to :organization
  has_many :jobs, dependent: :nullify
  has_many :worker_request_nonces, dependent: :delete_all
  has_many :worker_enrollment_grants, dependent: :delete_all
  has_many :worker_identity_events, dependent: :delete_all
  has_many :worker_pool_memberships, dependent: :destroy
  has_many :worker_pools, through: :worker_pool_memberships

  validates :name, presence: true
  validates :trust_tier, inclusion: { in: TRUST_TIERS }

  def trust_rank = TRUST_TIERS.index(trust_tier)

  def meets_trust?(minimum)
    trust_rank >= TRUST_TIERS.index(minimum.to_s)
  end

  class << self
    def issue!(**attributes)
      transaction do
        worker, plaintext = super
        grant = worker.issue_enrollment_grant!(plaintext)
        worker.record_identity_event!("grant_issued", expires_at: grant.expires_at)
        [ worker, plaintext ]
      end
    end
  end

  def issue_enrollment_grant!(plaintext)
    worker_enrollment_grants.create!(token_digest: self.class.token_digest(plaintext),
      token_hint: plaintext.first(12), expires_at: WorkerEnrollmentGrant::TTL.from_now)
  end

  def record_identity_event!(event_type, **details)
    worker_identity_events.create!(event_type:, key_fingerprint:, details: details.compact)
  end

  def enrolled? = public_key_pem.present? && key_fingerprint.present?

  def rotate_token!
    transaction do
      plaintext = super
      worker_enrollment_grants.active.update_all(revoked_at: Time.current, updated_at: Time.current)
      issue_enrollment_grant!(plaintext)
      previous_fingerprint = key_fingerprint
      update!(public_key_pem: nil, key_fingerprint: nil, enrolled_at: nil,
        identity_rotated_at: Time.current)
      worker_request_nonces.delete_all
      worker_identity_events.create!(event_type: "identity_reset", key_fingerprint: previous_fingerprint,
        details: { enrollment_expires_at: WorkerEnrollmentGrant::TTL.from_now })
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
