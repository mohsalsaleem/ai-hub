require "test_helper"

class PublicPagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page explains the product without authentication" do
    get root_path

    assert_response :success
    assert_select "h1", "Run private AI like a shared service."
    assert_select "a[href='#{docs_path}']", minimum: 1
    assert_select "a[href='#{new_registration_path}']", minimum: 1
    assert_select "a[href='https://github.com/mohsalsaleem/ai-hub'][target='_blank'][rel='noopener noreferrer']", 1
  end

  test "documentation is public and includes the integration contract" do
    get docs_path

    assert_response :success
    assert_select "h1", "Connect applications to private models."
    assert_match "/v1/responses", response.body
    assert_match "AI_HUB_WORKER_TOKEN", response.body
    assert_select "a[target='_blank'][rel='noopener noreferrer']", 6
  end

  test "llms documentation is public and describes the machine integration contract" do
    get "/llms.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match "## OpenAI-compatible API", response.body
    assert_match "## Native job API", response.body
    assert_match "## Task definitions", response.body
    assert_match "document.summarize@1", response.body
    assert_match "Definitions cannot be edited after publication", response.body
    assert_match "MCP is planned but is not currently exposed", response.body
    assert_no_match(/aih_[0-9a-f]{48}/, response.body)
  end

  test "signed-in visitors use the dashboard" do
    sign_in_as(users(:one))

    get root_path

    assert_redirected_to dashboard_path
  end
end
