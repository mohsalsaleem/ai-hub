class WorkerIdentityEvent < ApplicationRecord
  EVENT_TYPES = %w[grant_issued enrolled identity_reset revoked trust_changed pools_changed].freeze

  belongs_to :worker

  validates :event_type, inclusion: { in: EVENT_TYPES }
end
