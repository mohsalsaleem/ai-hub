require "test_helper"

class HomebaseSessionVerifierTest < ActiveSupport::TestCase
  setup do
    @issuer = ENV["OIDC_ISSUER"]; ENV["OIDC_ISSUER"]="https://identity.example.test"
    @user = users(:one)
    @user.external_identities.create!(issuer: ENV["OIDC_ISSUER"], subject: "owner")
    @record = @user.sessions.create!(homebase_issuer: ENV["OIDC_ISSUER"], homebase_subject: "owner", homebase_expires_at: 1.hour.from_now,
      homebase_tokens: { "access_token"=>"access", "refresh_token"=>"refresh", "expires_at"=>1.hour.from_now.to_f*1000 }.to_json)
    @access_original = HomebaseAccess.method(:check!)
    HomebaseAccess.define_singleton_method(:check!) { |*| true }
    @fake = Object.new
    @fake.define_singleton_method(:active?) { |*| true }
  end
  teardown do
    @issuer ? ENV["OIDC_ISSUER"]=@issuer : ENV.delete("OIDC_ISSUER")
    HomebaseAccess.define_singleton_method(:check!, @access_original)
  end
  test "checks central status and keeps organization ownership" do
    assert HomebaseSessionVerifier.valid?(@record, identity: @fake)
    assert_equal @user.id, @record.user_id
  end
  test "expired app sessions and removed mappings cannot resume" do
    @record.update!(homebase_expires_at: 1.minute.ago)
    assert_not HomebaseSessionVerifier.valid?(@record, identity: @fake)
    @record.update!(homebase_expires_at: 1.hour.from_now)
    @user.external_identities.destroy_all
    assert_not HomebaseSessionVerifier.valid?(@record, identity: @fake)
  end
  test "inactive tokens do not authenticate" do
    @fake.define_singleton_method(:active?) { |*| false }
    assert_not HomebaseSessionVerifier.valid?(@record, identity: @fake)
  end
  test "revoked app grants are denied" do
    HomebaseAccess.define_singleton_method(:check!) { |*| raise HomebaseAccess::Denied }
    assert_raises(HomebaseAccess::Denied) { HomebaseSessionVerifier.valid?(@record, identity: @fake) }
  end
  test "rejected refresh grant leads to new login" do
    expire_access
    @fake.define_singleton_method(:refresh) { |*| raise HomebaseIdentityClient::ExpiredGrant }
    assert_not HomebaseSessionVerifier.valid?(@record, identity: @fake)
  end
  test "provider outage preserves the existing session" do
    expire_access
    @fake.define_singleton_method(:refresh) { |*| raise Timeout::Error }
    assert_raises(HomebaseAccess::Unavailable) { HomebaseSessionVerifier.valid?(@record, identity: @fake) }
    assert Session.exists?(@record.id)
  end
  test "refresh rotation is persisted encrypted" do
    expire_access
    @fake.define_singleton_method(:refresh) { |*| { "access_token"=>"new-access", "refresh_token"=>"new-refresh", "expires_at"=>1.hour.from_now.to_f*1000 } }
    assert HomebaseSessionVerifier.valid?(@record, identity: @fake)
    assert_equal "new-refresh", JSON.parse(@record.reload.homebase_tokens)["refresh_token"]
    assert_not_includes @record.homebase_tokens_before_type_cast, "new-refresh"
  end
  def expire_access
    @record.update!(homebase_tokens: { "access_token"=>"access", "refresh_token"=>"refresh", "expires_at"=>0 }.to_json)
  end
end
