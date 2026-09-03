require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows operations dashboard in development and test" do
    sign_in_as(users(:one))
    get dashboard_path
    assert_response :success
    assert_select "h1", "Overview"
    assert_match(/Recent jobs/, response.body)
  end
end
