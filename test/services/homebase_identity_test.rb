require "test_helper"

class HomebaseIdentityTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h.slice("OIDC_ISSUER", "OIDC_CLIENT_ID", "PUBLIC_URL", "OIDC_CLIENT_SECRET")
    ENV["OIDC_ISSUER"]="https://identity.example.test/realms/homebase"
    ENV["OIDC_CLIENT_ID"]="aihub"
    ENV["PUBLIC_URL"]="https://aihub.example.test"
    ENV["OIDC_CLIENT_SECRET"]="test-secret"
    @key = OpenSSL::PKey::RSA.generate(2048)
    @jwk = JSON::JWK.new(@key.public_key)
    @client = HomebaseIdentityClient.new
    jwk = @jwk
    @client.define_singleton_method(:metadata) { { "jwks_uri"=>"https://identity.example.test/keys", "token_endpoint"=>"https://identity.example.test/token" } }
    @client.define_singleton_method(:request_json) { |*| { "keys"=>[ jwk ] } }
    @claims = { iss: HomebaseSettings.issuer, sub: "owner", aud: "aihub", iat: Time.now.to_i, exp: Time.now.to_i+300, nonce: "nonce" }
  end
  teardown do
    %w[OIDC_ISSUER OIDC_CLIENT_ID PUBLIC_URL OIDC_CLIENT_SECRET].each { |key| ENV.delete(key) }; ENV.update(@env)
  end
  def token(claims = @claims, key = @key)
    JSON::JWT.new(claims).tap { |jwt| jwt.kid = @jwk[:kid] }.sign(key, :RS256).to_s
  end
  test "valid provider signature and claims accepted" do
    assert_equal "owner", @client.verify_id_token(token, "nonce")["sub"]
  end
  test "invalid signature and identity claims rejected" do
    [ { iss: "https://attacker.test" }, { aud: "other" }, { exp: 1 }, { nonce: "wrong" }, { azp: "other" }, { iat: Time.now.to_i+600 } ].each do |override|
      assert_raises(StandardError) { @client.verify_id_token(token(@claims.merge(override)), "nonce") }
    end
    assert_raises(StandardError) { @client.verify_id_token(token(@claims, OpenSSL::PKey::RSA.generate(2048)), "nonce") }
  end
  test "confirmation requires recent provider authentication time" do
    transaction = { "purpose"=>"link", "nonce"=>"nonce", "verifier"=>"verifier", "started_at"=>Time.now.to_i }
    issuer = @client
    [ nil, Time.now.to_i-3600, Time.now.to_i+3600 ].each do |time|
      raw = token(@claims.merge(auth_time: time))
      # Keep the real signature check against the known signing key.
      jwk = @jwk
      issuer.define_singleton_method(:request_json) do |address, *|
        address.end_with?("/token") ? { "id_token"=>raw, "access_token"=>"access" } : { "keys"=>[ jwk ] }
      end
      assert_raises(HomebaseIdentityClient::InvalidIdentity) { issuer.exchange("code", transaction) }
    end
    raw = token(@claims.merge(auth_time: Time.now.to_i)); jwk = @jwk
    issuer.define_singleton_method(:request_json) { |address, *| address.end_with?("/token") ? { "id_token"=>raw, "access_token"=>"access" } : { "keys"=>[ jwk ] } }
    assert_equal "owner", issuer.exchange("code", transaction).last["sub"]
  end
  test "authorization uses PKCE and fresh login for confirmation" do
    @client.define_singleton_method(:metadata) { { "authorization_endpoint"=>"https://identity.example.test/authorize", "token_endpoint"=>"https://identity.example.test/token" } }
    url = URI(@client.authorize({ "purpose"=>"link", "state"=>"state", "nonce"=>"nonce", "verifier"=>"test-verifier" }))
    values = URI.decode_www_form(url.query).to_h
    assert_equal "S256", values["code_challenge_method"]
    assert_equal Base64.urlsafe_encode64(Digest::SHA256.digest("test-verifier"), padding: false), values["code_challenge"]
    assert_equal "https://aihub.example.test/auth/homebase/callback", values["redirect_uri"]
    assert_equal "login", values["prompt"]
    assert_equal "0", values["max_age"]
    assert_equal "nonce", values["nonce"]
    assert_equal "state", values["state"]
  end
  test "return destinations reject other origins and control characters" do
    [ "//attacker.test", "https://attacker.test", "/\\attacker.test", "/\nattack" ].each do |value|
      assert_equal "/dashboard", HomebaseSettings.safe_path(value)
    end
    assert_equal "/security", HomebaseSettings.safe_path("/security")
  end
end
