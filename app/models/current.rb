class Current < ActiveSupport::CurrentAttributes
  attribute :session, :organization, :platform_session
  delegate :user, to: :session, allow_nil: true
  delegate :platform_operator, to: :platform_session, allow_nil: true
end
