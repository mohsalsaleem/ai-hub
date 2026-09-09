class Session < ApplicationRecord
  belongs_to :user

  def homebase? = homebase_issuer.present?

  # Keep provider credentials encrypted with a purpose-specific key derived from
  # the existing stable Rails secret. Never put provider tokens in browser cookies.
  def homebase_tokens=(value)
    super(value.nil? ? nil : token_encryptor.encrypt_and_sign(value))
  end

  def homebase_tokens
    value = super
    value.nil? ? nil : token_encryptor.decrypt_and_verify(value)
  end

  private

  def token_encryptor
    key = Rails.application.key_generator.generate_key("ai-hub/homebase-session-tokens/v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end
end
