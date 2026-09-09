require "test_helper"

class HomebaseTenantBoundariesTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @previous = ENV.to_h.slice("HOMEBASE_AUTH_MODE", "OIDC_ISSUER", "OIDC_CLIENT_SECRET", "PUBLIC_URL", "HOMEBASE_URL", "HOMEBASE_APP_KEY")
    ENV.update("HOMEBASE_AUTH_MODE" => "linking", "OIDC_ISSUER" => "https://identity.example.test/realms/homebase",
      "OIDC_CLIENT_SECRET" => "test", "PUBLIC_URL" => "https://www.example.com", "HOMEBASE_URL" => "https://homebase.example.test", "HOMEBASE_APP_KEY" => "test")
    @user = users(:one)
    @user.external_identities.create!(issuer: HomebaseSettings.issuer, subject: "owner")
    sign_in_as(@user)
    Current.session.update!(homebase_issuer: HomebaseSettings.issuer, homebase_subject: "owner",
      homebase_expires_at: 1.hour.from_now, homebase_tokens: { access_token: "access", refresh_token: "refresh", expires_at: 0 }.to_json)
    @record = Current.session
    Current.reset
    @verify = HomebaseSessionVerifier.method(:valid?)
    HomebaseSessionVerifier.define_singleton_method(:valid?) { |*| true }
  end

  teardown do
    %w[HOMEBASE_AUTH_MODE OIDC_ISSUER OIDC_CLIENT_SECRET PUBLIC_URL HOMEBASE_URL HOMEBASE_APP_KEY].each { |key| ENV.delete(key) }
    ENV.update(@previous)
    HomebaseSessionVerifier.define_singleton_method(:valid?, @verify)
  end

  test "Homebase user creates and rotates application credentials in their organization" do
    post applications_path, params: { hub_application: { name: "Linked app", slug: "linked-app" } }
    app = HubApplication.find_by!(slug: "linked-app")
    assert_equal organizations(:one).id, app.organization_id
    assert_redirected_to application_path(app)
    old_digest = app.token_digest
    post rotate_token_application_path(app)
    assert_not_equal old_digest, app.reload.token_digest
    other, = HubApplication.issue!(organization: organizations(:two), name: "Other", slug: "other")
    post rotate_token_application_path(other)
    assert_response :not_found
    get platform_root_path
    assert_redirected_to new_platform_session_path
  end

  test "members keep their role after Homebase login" do
    memberships(:one_owner).update!(role: "member")
    assert_no_difference("HubApplication.count") do
      post applications_path, params: { hub_application: { name: "Forbidden", slug: "forbidden" } }
    end
    assert_redirected_to dashboard_path
  end

  test "public registration and unrelated password logins remain available" do
    get new_registration_path
    assert_response :success
    post session_path, params: { email_address: users(:two).email_address, password: "password" }
    assert_redirected_to dashboard_path
    get dashboard_path
    assert_response :success
    assert_includes response.body, organizations(:two).name
    assert_equal users(:two).id, Session.order(:id).last.user_id
  end

  test "provider outage preserves session and password recovery path" do
    HomebaseSessionVerifier.define_singleton_method(:valid?) { |*| raise HomebaseAccess::Unavailable }
    get dashboard_path
    assert_response :service_unavailable
    assert_select "a[href='#{new_session_path}']"
    assert Session.exists?(@record.id)
    get new_session_path
    assert_response :success
    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to dashboard_path
    get dashboard_path
    assert_response :success
  end

  test "revoked Homebase access denies that session without disabling public sign in" do
    HomebaseSessionVerifier.define_singleton_method(:valid?) { |*| raise HomebaseAccess::Denied }
    get dashboard_path
    assert_response :forbidden
    get new_session_path
    assert_response :success
  end

  test "expired provider session is removed" do
    HomebaseSessionVerifier.define_singleton_method(:valid?) { |*| false }
    get dashboard_path
    assert_redirected_to new_session_path
    assert_not Session.exists?(@record.id)
  end

  test "logout can clear a provider session during an outage without touching credentials" do
    app, token = HubApplication.issue!(organization: organizations(:one), name: "Automation", slug: "automation")
    original = HomebaseIdentityClient.method(:new)
    HomebaseIdentityClient.define_singleton_method(:new) { raise HomebaseAccess::Unavailable }
    delete session_path
    assert_redirected_to new_session_path
    assert_not Session.exists?(@record.id)
    assert_equal app, HubApplication.authenticate(token)
  ensure
    HomebaseIdentityClient.define_singleton_method(:new, original)
  end
end
