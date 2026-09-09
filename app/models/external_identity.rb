class ExternalIdentity < ApplicationRecord
  belongs_to :user
  validates :issuer, :subject, presence: true
  validates :subject, uniqueness: { scope: :issuer }
  validates :user_id, uniqueness: { scope: :issuer }
end
