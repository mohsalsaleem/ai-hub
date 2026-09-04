require "test_helper"

class PlatformAuditEventTest < ActiveSupport::TestCase
  test "audit events cannot be changed or deleted" do
    operator = PlatformOperator.create!(email_address: "audit@example.com",
      password: "operator-password")
    event = PlatformAuditEvent.create!(platform_operator: operator, action: "shared_pool.approved",
      subject_type: "WorkerPool", subject_id: 12, subject_label: "Shared GPU")

    assert_not event.update(action: "shared_pool.revoked")
    assert_not event.destroy
    assert_equal "shared_pool.approved", event.reload.action
    assert PlatformAuditEvent.exists?(event.id)
  end
end
