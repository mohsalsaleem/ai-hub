module TokenAuthenticatable
  extend ActiveSupport::Concern

  class_methods do
    def issue!(**attributes)
      plaintext = "aih_#{SecureRandom.hex(24)}"
      record = create!(**attributes, token_digest: token_digest(plaintext))
      [ record, plaintext ]
    end

    def authenticate(plaintext)
      return if plaintext.blank?

      find_by(token_digest: token_digest(plaintext), active: true)
    end

    def token_digest(plaintext)
      OpenSSL::Digest::SHA256.hexdigest(plaintext.to_s)
    end
  end
end
