class Worker < ApplicationRecord
  include TokenAuthenticatable

  belongs_to :organization
  has_many :jobs, dependent: :nullify

  validates :name, presence: true

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
