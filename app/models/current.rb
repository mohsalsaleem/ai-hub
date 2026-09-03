class Current < ActiveSupport::CurrentAttributes
  attribute :session, :organization
  delegate :user, to: :session, allow_nil: true
end
