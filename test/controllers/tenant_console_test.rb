require "test_helper"

class TenantConsoleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @application, = HubApplication.issue!(organization: organizations(:one), name: "First App", slug: "first-app")
    @other_application, = HubApplication.issue!(organization: organizations(:two), name: "Private App", slug: "private-app")
  end

  test "application pages only expose the current organization" do
    get applications_path
    assert_response :success
    assert_match "First App", response.body
    assert_no_match "Private App", response.body

    get application_path(@other_application)
    assert_response :not_found
  end

  test "owner creates an application and sees its token once" do
    assert_difference "organizations(:one).hub_applications.count", 1 do
      post applications_path, params: { hub_application: { name: "Created App", slug: "created-app" } }
    end
    follow_redirect!
    assert_response :success
    assert_match(/aih_[0-9a-f]{48}/, response.body)
    get request.path
    assert_no_match(/aih_[0-9a-f]{48}/, response.body)
  end
end
