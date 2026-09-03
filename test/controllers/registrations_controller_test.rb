require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "open signup creates a user and isolated organization" do
    assert_difference [ "User.count", "Organization.count", "Membership.count" ], 1 do
      post registration_path, params: { user: { email_address: "new@example.com",
        password: "long-enough", organization_name: "New Company" } }
    end

    assert_redirected_to root_path
    user = User.find_by!(email_address: "new@example.com")
    assert_equal "New Company", user.organizations.sole.name
    assert user.memberships.sole.owner?
  end
end
