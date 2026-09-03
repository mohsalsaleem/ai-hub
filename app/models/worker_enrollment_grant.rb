class WorkerEnrollmentGrant < ApplicationRecord
  TTL = 24.hours

  belongs_to :worker

  validates :token_digest, :expires_at, presence: true
  validates :token_digest, uniqueness: true

  scope :active, -> { where(used_at: nil, revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.authenticate(plaintext)
    return if plaintext.blank?

    active.includes(:worker).find_by(token_digest: Worker.token_digest(plaintext))&.then do |grant|
      grant if grant.worker.active?
    end
  end

  def usable? = used_at.nil? && revoked_at.nil? && expires_at.future? && worker.active?

  def consume!
    update!(used_at: Time.current)
  end
end
