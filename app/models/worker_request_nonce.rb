class WorkerRequestNonce < ApplicationRecord
  belongs_to :worker

  validates :nonce_digest, :expires_at, presence: true
end
