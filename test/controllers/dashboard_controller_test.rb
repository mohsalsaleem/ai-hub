require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows operations dashboard in development and test" do
    get root_path
    assert_response :success
    assert_select "h1", "Private models, shared safely."
    assert_match(/Recent jobs/, response.body)
  end
end
