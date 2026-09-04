class PlatformAuditEvent < ApplicationRecord
  belongs_to :platform_operator

  validates :action, :subject_type, :subject_id, :subject_label, presence: true

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "Platform audit events are immutable")
    throw :abort
  end
end
