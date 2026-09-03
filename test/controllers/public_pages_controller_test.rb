require "test_helper"

class PublicPagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page explains the product without authentication" do
    get root_path

    assert_response :success
    assert_select "h1", "Run private AI like a shared service."
    assert_select "a[href='#{docs_path}']", minimum: 1
    assert_select "a[href='#{new_registration_path}']", minimum: 1
  end

  test "documentation is public and includes the integration contract" do
    get docs_path

    assert_response :success
    assert_select "h1", "Connect applications to private models."
    assert_match "/v1/responses", response.body
    assert_match "AI_HUB_WORKER_TOKEN", response.body
  end

  test "signed-in visitors use the dashboard" do
    sign_in_as(users(:one))

    get root_path

    assert_redirected_to dashboard_path
  end
end
