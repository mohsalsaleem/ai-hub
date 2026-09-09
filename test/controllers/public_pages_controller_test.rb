require "test_helper"

class PublicPagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page explains the product without authentication" do
    get root_path

    assert_response :success
    assert_select "h1", "Run private AI like a shared service."
    assert_select "a[href='#{docs_path}']", minimum: 1
    assert_select "a[href='#{new_registration_path}']", minimum: 1
    assert_select "a[href='https://github.com/mohsalsaleem/ai-hub'][target='_blank'][rel='noopener noreferrer']", 1
    assert_select ".site-brand svg.brand-mark[aria-hidden='true']", 1
    assert_select "link[rel='icon'][href='/icon.svg'][type='image/svg+xml']", 1
    assert_select "link[rel='icon'][href='/favicon.ico']", 1
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png']", 1
    assert_select "link[rel='manifest'][href='/manifest.webmanifest']", 1
  end

  test "browser and installable app icons are present" do
    %w[icon.svg icon.png icon-192.png icon-maskable.png apple-touch-icon.png favicon.ico manifest.webmanifest].each do |asset|
      assert File.exist?(Rails.public_path.join(asset)), "Expected public/#{asset} to exist"
    end

    manifest = JSON.parse(Rails.public_path.join("manifest.webmanifest").read)
    assert_equal "AI Hub", manifest.fetch("name")
    assert_equal "#0c0d11", manifest.fetch("theme_color")
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
