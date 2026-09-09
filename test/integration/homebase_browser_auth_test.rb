require "test_helper"

class HomebaseBrowserAuthTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @previous = ENV.to_h.slice("HOMEBASE_AUTH_MODE", "OIDC_ISSUER", "OIDC_CLIENT_SECRET", "PUBLIC_URL", "HOMEBASE_URL", "HOMEBASE_APP_KEY", "HOMEBASE_ALLOW_LOCAL_HTTP")
    ENV.update("HOMEBASE_AUTH_MODE"=>"linking", "OIDC_ISSUER"=>"https://identity.example.test/realms/homebase", "OIDC_CLIENT_SECRET"=>"test-only",
      "PUBLIC_URL"=>"https://www.example.com", "HOMEBASE_URL"=>"https://homebase.example.test", "HOMEBASE_APP_KEY"=>"test-only")
    @user = users(:one)
    @fake = Object.new
    @claims = { "iss"=>HomebaseSettings.issuer, "sub"=>"owner-subject" }
    claims = @claims
    @fake.define_singleton_method(:authorize) { |tx| "https://identity.example.test/authorize?state=#{tx.fetch('state')}" }
    @fake.define_singleton_method(:exchange) { |*, **| [ { "access_token"=>"test-access", "refresh_token"=>"test-refresh", "expires_at"=>1.hour.from_now.to_f*1000 }, claims ] }
  end
  teardown do
    %w[HOMEBASE_AUTH_MODE OIDC_ISSUER OIDC_CLIENT_SECRET PUBLIC_URL HOMEBASE_URL HOMEBASE_APP_KEY HOMEBASE_ALLOW_LOCAL_HTTP].each { |key| ENV.delete(key) }
    ENV.update(@previous)
  end
  def with_stub(target, method, value)
    original = target.method(method)
    target.define_singleton_method(method) { |*, **| value }
    yield
  ensure
    target.define_singleton_method(method, original)
  end
  def with_provider(&block)
    with_stub(HomebaseIdentityClient, :new, @fake) { with_stub(HomebaseAccess, :check!, true, &block) }
  end
  def finish(state = HomebaseLoginTransaction.last.state)
    get "/auth/homebase/callback", params: { code: "test-code", state: state }
  end
  def map_user(user = @user)
    user.external_identities.create!(issuer: HomebaseSettings.issuer, subject: "owner-subject")
  end
  test "Homebase login preserves a protected local destination" do
    get account_security_path
    assert_redirected_to new_session_path
    with_provider { get homebase_login_path }
    assert_equal "/account/security", HomebaseLoginTransaction.last.return_to
  end
  test "linking rejects a missing Rails CSRF token" do
    sign_in_as(@user)
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference("HomebaseLoginTransaction.count") do
      post homebase_link_path, params: { password: "password" }
    end
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
  test "linking UI and local password login remain available" do
    get new_session_path
    assert_select 'a[href="/auth/homebase"]', "Continue with Homebase"
    assert_select 'input[name="password"]'
    sign_in_as(@user)
    get account_security_path
    assert_select 'form[action="/auth/homebase/link"]'
  end
  test "links the existing user without changing memberships or creating users" do
    sign_in_as(@user)
    original = @user.memberships.pluck(:organization_id, :role)
    with_provider do
      assert_no_difference("User.count") do
        post homebase_link_path, params: { password: "password" }
        finish
      end
    end
    assert_redirected_to account_security_path
    assert_equal @user.id, ExternalIdentity.last.user_id
    assert_equal original, @user.memberships.pluck(:organization_id, :role)
    get account_security_path
    assert_select 'form[action="/auth/homebase/link"]', count: 0
    assert_includes response.body, "Homebase is linked"
  end
  test "requires local password proof before linking" do
    sign_in_as(@user)
    assert_no_difference("HomebaseLoginTransaction.count") { post homebase_link_path, params: { password: "wrong" } }
    assert_redirected_to account_security_path
  end
  test "does not merge an unknown identity by email or register a user" do
    @claims["email"] = @user.email_address
    with_provider do
      assert_no_difference("User.count") { get homebase_login_path; finish }
    end
    assert_redirected_to new_session_path
    assert_equal 0, ExternalIdentity.count
  end
  test "linked identity creates an encrypted provider session for the original user" do
    map_user
    with_provider { get homebase_login_path; finish }
    assert_redirected_to dashboard_path
    record = @user.sessions.order(:id).last
    assert record.homebase?
    assert_equal "owner-subject", record.homebase_subject
    assert_operator record.homebase_expires_at, :<=, 8.hours.from_now
    encrypted = Session.connection.select_value("SELECT homebase_tokens FROM sessions WHERE id=#{record.id}")
    assert_not_includes encrypted, "test-access"
  end
  test "rejects changed state and consumes the transaction once" do
    map_user
    with_provider do
      get homebase_login_path
      assert_no_difference("Session.count") { finish("wrong") }
      assert_redirected_to new_session_path
      assert_equal 0, HomebaseLoginTransaction.count
    end
  end
  test "rejects expired transaction" do
    with_provider do
      get homebase_login_path
      state = HomebaseLoginTransaction.last.state
      HomebaseLoginTransaction.last.update!(expires_at: 1.minute.ago)
      assert_no_difference("Session.count") { finish(state) }
    end
    assert_redirected_to new_session_path
  end
  test "identity cannot be linked to a second account" do
    map_user(users(:two))
    sign_in_as(@user)
    with_provider { post homebase_link_path, params: { password: "password" }; finish }
    assert_redirected_to new_session_path
    assert_equal users(:two).id, ExternalIdentity.last.user_id
  end
  test "link callback is rejected after browser session changes" do
    sign_in_as(@user)
    with_provider do
      post homebase_link_path, params: { password: "password" }
      sign_in_as(users(:two))
      finish
    end
    assert_equal 0, ExternalIdentity.count
    assert_redirected_to new_session_path
  end
  test "off mode hides entry points and rejects linking" do
    ENV["HOMEBASE_AUTH_MODE"] = "off"
    get new_session_path
    assert_select "a[href='/auth/homebase']", count: 0
    get homebase_login_path
    assert_response :not_found
    post homebase_link_path
    assert_response :not_found
  end

  test "completed transactions cannot be replayed" do
    map_user
    with_provider do
      get homebase_login_path
      state = HomebaseLoginTransaction.last.state
      finish(state)
      assert_no_difference("Session.count") { finish(state) }
      assert_redirected_to new_session_path
    end
  end

  test "accounts without organizations can still link their identity" do
    @user.memberships.destroy_all
    sign_in_as(@user)
    get account_security_path
    assert_response :success
    with_provider do
      post homebase_link_path, params: { password: "password" }
      finish
    end
    assert_redirected_to account_security_path
    assert_equal @user.id, ExternalIdentity.last.user_id
    assert_equal 0, @user.memberships.count
  end
end
