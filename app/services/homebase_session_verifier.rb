class HomebaseSessionVerifier
  # Single Puma process: serialize rotated refresh tokens across parallel requests.
  LOCK = Mutex.new
  def self.valid?(record, identity: HomebaseIdentityClient.new)
    LOCK.synchronize do
      record.reload
      return false if record.homebase_expires_at.nil? || record.homebase_expires_at <= Time.current || record.homebase_issuer != HomebaseSettings.issuer
      mapping = record.user.external_identities.find_by(issuer: record.homebase_issuer, subject: record.homebase_subject)
      return false unless mapping
      HomebaseAccess.check!(mapping.issuer, mapping.subject)
      tokens = JSON.parse(record.homebase_tokens)
      if tokens.fetch("expires_at") < (Time.current.to_f * 1000).to_i + 30_000
        tokens = identity.refresh(tokens)
        record.update!(homebase_tokens: tokens.to_json)
      end
      identity.active?(tokens, mapping.subject)
    end
  rescue HomebaseIdentityClient::ExpiredGrant, ActiveRecord::RecordNotFound
    false
  rescue HomebaseAccess::Denied
    raise
  rescue StandardError
    raise HomebaseAccess::Unavailable
  end
end
