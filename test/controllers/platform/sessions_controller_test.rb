require "test_helper"

class Platform::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @operator = PlatformOperator.create!(email_address: "operator@example.com",
      password: "operator-password")
  end

  test "new uses the separate platform sign in" do
    get new_platform_session_path

    assert_response :success
    assert_select "h1", "Platform sign in"
    assert_select "form[action='#{platform_session_path}']"
  end
  test "tenant session does not wrap the platform sign in" do
    sign_in_as(users(:one))

    get new_platform_session_path

    assert_response :success
    assert_select "h1", "Platform sign in"
    assert_select "nav[aria-label='Main navigation']", count: 0
  end


  test "valid credentials create only a platform session" do
    post platform_session_path,
      params: { email_address: @operator.email_address, password: "operator-password" }

    assert_redirected_to platform_root_path
    assert cookies[:platform_session_id]
    assert_nil cookies[:session_id]
    assert_equal 1, @operator.platform_sessions.count
  end

  test "tenant credentials cannot authenticate to the platform" do
    post platform_session_path,
      params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to new_platform_session_path
    assert_nil cookies[:platform_session_id]
  end

  test "disabled operators cannot authenticate" do
    @operator.update!(active: false)

    post platform_session_path,
      params: { email_address: @operator.email_address, password: "operator-password" }

    assert_redirected_to new_platform_session_path
    assert_nil cookies[:platform_session_id]
  end

  test "destroy removes the platform session" do
    sign_in_as_platform_operator(@operator)

    delete platform_session_path

    assert_redirected_to new_platform_session_path
    assert_empty cookies[:platform_session_id]
    assert_empty @operator.platform_sessions.reload
  end
end
