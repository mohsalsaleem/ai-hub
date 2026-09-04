class Worker < ApplicationRecord
  include TokenAuthenticatable

  TRUST_TIERS = %w[external verified organization owner].freeze
  PARTICIPATION_MODES = %w[private shared].freeze
  AVAILABILITY_DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
  TIME_PATTERN = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :organization
  has_many :jobs, dependent: :nullify
  has_many :routing_decisions, dependent: :nullify
  has_many :job_executions, dependent: :nullify
  has_many :worker_request_nonces, dependent: :delete_all
  has_many :worker_enrollment_grants, dependent: :delete_all
  has_many :worker_identity_events, dependent: :delete_all
  has_many :worker_pool_memberships, dependent: :destroy
  has_many :worker_pools, through: :worker_pool_memberships

  validates :name, presence: true
  validates :trust_tier, inclusion: { in: TRUST_TIERS }
  validates :participation_mode, inclusion: { in: PARTICIPATION_MODES }
  validates :availability_timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates :availability_days, presence: true
  validates :max_concurrent_jobs, numericality: { only_integer: true, in: 1..100 }
  validate :availability_days_are_valid
  validate :availability_window_is_valid
  before_validation :normalize_availability_policy

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

  def paused? = paused_at.present?

  def accepting_jobs?(now: Time.current)
    active? && !paused? && scheduled_available_at?(now) && active_lease_count(now:) < max_concurrent_jobs
  end

  def participation_state(now: Time.current)
    return "revoked" unless active?
    return "paused" if paused?
    return "scheduled_offline" unless scheduled_available_at?(now)
    return "offline" unless online?
    return "busy" if active_lease_count(now:) >= max_concurrent_jobs

    "available"
  end

  def active_lease_count(now: Time.current)
    jobs.where(status: "leased").where("leased_until > ?", now).count
  end

  def scheduled_available_at?(time = Time.current)
    local_time = time.in_time_zone(availability_timezone)
    return availability_days.include?(local_time.strftime("%A").downcase) if all_day_schedule?

    minute = local_time.hour * 60 + local_time.min
    start_minute = minutes_since_midnight(availability_starts_at)
    end_minute = minutes_since_midnight(availability_ends_at)
    schedule_day = if start_minute > end_minute && minute < end_minute
      (local_time.to_date - 1.day).strftime("%A").downcase
    else
      local_time.strftime("%A").downcase
    end

    availability_days.include?(schedule_day) && within_window?(minute, start_minute, end_minute)
  end

  def availability_summary
    days = availability_days == AVAILABILITY_DAYS ? "Every day" : availability_days.map { |day| day.first(3).capitalize }.join(", ")
    window = all_day_schedule? ? "all day" : "#{availability_starts_at} to #{availability_ends_at}"
    "#{days}, #{window} (#{availability_timezone})"
  end

  private

  def normalize_availability_policy
    self.availability_days = Array(availability_days).compact_blank.uniq
    self.availability_starts_at = availability_starts_at.presence
    self.availability_ends_at = availability_ends_at.presence
  end

  def availability_days_are_valid
    invalid_days = Array(availability_days) - AVAILABILITY_DAYS
    errors.add(:availability_days, "contains invalid days") if invalid_days.any?
  end

  def availability_window_is_valid
    values = [ availability_starts_at, availability_ends_at ]
    return if values.all?(&:blank?)

    if values.any?(&:blank?)
      errors.add(:availability_starts_at, "and end time must both be set")
    elsif values.any? { |value| !TIME_PATTERN.match?(value) }
      errors.add(:availability_starts_at, "and end time must use HH:MM")
    elsif availability_starts_at == availability_ends_at
      errors.add(:availability_ends_at, "must differ from the start time")
    end
  end

  def all_day_schedule? = availability_starts_at.blank? && availability_ends_at.blank?

  def minutes_since_midnight(value)
    hour, minute = value.split(":").map(&:to_i)
    hour * 60 + minute
  end

  def within_window?(minute, start_minute, end_minute)
    if start_minute < end_minute
      minute >= start_minute && minute < end_minute
    else
      minute >= start_minute || minute < end_minute
    end
  end
end
