require "test_helper"

class WorkerEnrollmentGrantTest < ActiveSupport::TestCase
  test "worker issuance creates an expiring enrollment grant" do
    worker, token = Worker.issue!(organization: organizations(:one), name: "New worker")
    grant = worker.worker_enrollment_grants.sole

    assert_equal token.first(12), grant.token_hint
    assert_in_delta WorkerEnrollmentGrant::TTL.from_now, grant.expires_at, 2.seconds
    assert_equal grant, WorkerEnrollmentGrant.authenticate(token)
  end

  test "used and expired grants cannot authenticate" do
    worker, token = Worker.issue!(organization: organizations(:one), name: "New worker")
    grant = worker.worker_enrollment_grants.sole

    grant.consume!
    assert_nil WorkerEnrollmentGrant.authenticate(token)

    expired_worker, expired_token = Worker.issue!(organization: organizations(:one), name: "Expired worker")
    expired_worker.worker_enrollment_grants.sole.update!(expires_at: 1.minute.ago)
    assert_nil WorkerEnrollmentGrant.authenticate(expired_token)
  end
end
