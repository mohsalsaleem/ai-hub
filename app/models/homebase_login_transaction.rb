class HomebaseLoginTransaction < ApplicationRecord
  def self.issue!(purpose:, user: nil, browser_session: nil, return_to: "/dashboard")
    where("expires_at < ?", Time.current).delete_all
    raw = SecureRandom.urlsafe_base64(32)
    row = create!(token_digest: Digest::SHA256.hexdigest(raw), purpose: purpose, user_id: user&.id,
      browser_session_id: browser_session&.id, issuer: HomebaseSettings.issuer,
      state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32),
      verifier: SecureRandom.urlsafe_base64(48), return_to: HomebaseSettings.safe_path(return_to), expires_at: 10.minutes.from_now)
    [ raw, row ]
  end
  def self.consume!(raw)
    raise HomebaseIdentityClient::InvalidIdentity if raw.blank?
    row = find_by(token_digest: Digest::SHA256.hexdigest(raw))
    raise HomebaseIdentityClient::InvalidIdentity unless row && where(id: row.id).delete_all == 1 && row.expires_at > Time.current
    row
  end
  def protocol_data = attributes.merge("started_at" => created_at.to_i)
end
