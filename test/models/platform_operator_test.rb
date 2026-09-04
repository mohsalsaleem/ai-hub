require "test_helper"

class PlatformOperatorTest < ActiveSupport::TestCase
  test "platform identity is independent from tenant users" do
    tenant = users(:one)
    operator = PlatformOperator.create!(email_address: tenant.email_address,
      password: "operator-password")

    assert operator.authenticate("operator-password")
    assert_not_equal tenant.password_digest, operator.password_digest
    assert_equal tenant.email_address, operator.email_address
  end
end
