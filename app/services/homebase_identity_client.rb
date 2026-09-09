require "net/http"
class HomebaseIdentityClient
  class InvalidIdentity < StandardError; end
  def metadata
    @metadata ||= begin
      info = request_json(HomebaseSettings.issuer + "/.well-known/openid-configuration")
      raise InvalidIdentity unless info["issuer"] == HomebaseSettings.issuer
      %w[authorization_endpoint token_endpoint jwks_uri introspection_endpoint end_session_endpoint].each do |key|
        uri = URI(info.fetch(key))
        expected = URI(HomebaseSettings.issuer)
        raise InvalidIdentity unless [ uri.scheme, uri.host, uri.port ] == [ expected.scheme, expected.host, expected.port ] && uri.userinfo.nil?
      end
      info
    end
  end
  def client
    OpenIDConnect::Client.new(identifier: HomebaseSettings.client_id, secret: ENV.fetch("OIDC_CLIENT_SECRET"), redirect_uri: HomebaseSettings.origin + "/auth/homebase/callback", authorization_endpoint: metadata.fetch("authorization_endpoint"), token_endpoint: metadata.fetch("token_endpoint"))
  end
  def authorize(transaction)
    options = { scope: %w[openid profile email], state: transaction.fetch("state"), nonce: transaction.fetch("nonce"),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(transaction.fetch("verifier")), padding: false), code_challenge_method: "S256" }
    options.merge!(prompt: "login", max_age: 0) if transaction["purpose"] != "login"
    client.authorization_uri(**options)
  end
  def exchange(code, transaction)
    token = request_json(metadata.fetch("token_endpoint"), grant_type: "authorization_code", code: code,
      redirect_uri: HomebaseSettings.origin + "/auth/homebase/callback", code_verifier: transaction.fetch("verifier"))
    claims = verify_id_token(token.fetch("id_token"), transaction.fetch("nonce"))
    if transaction["purpose"] != "login"
      time = claims["auth_time"]
      raise InvalidIdentity unless time.is_a?(Numeric) && time >= transaction.fetch("started_at") - 30 && time <= Time.now.to_i + 30
    end
    [ pack(token), claims ]
  end
  def verify_id_token(raw, nonce)
    keys = JSON::JWK::Set.new(request_json(metadata.fetch("jwks_uri")).fetch("keys"))
    jwt = JSON::JWT.decode(raw, keys, [ :RS256 ])
    token = OpenIDConnect::ResponseObject::IdToken.new(jwt)
    token.verify!(issuer: HomebaseSettings.issuer, audience: HomebaseSettings.client_id, nonce: nonce)
    raise InvalidIdentity if jwt["sub"].blank? || jwt["iat"].to_i > Time.now.to_i + 30
    raise InvalidIdentity if (jwt["azp"] && jwt["azp"] != HomebaseSettings.client_id) || (Array(jwt["aud"]).length > 1 && jwt["azp"] != HomebaseSettings.client_id)
    jwt.to_h
  end
  class ExpiredGrant < InvalidIdentity; end
  def refresh(tokens)
    data = request_json(metadata.fetch("token_endpoint"), grant_type: "refresh_token", refresh_token: tokens.fetch("refresh_token"))
    pack(data, tokens)
  end
  def active?(tokens, subject)
    info = request_json(metadata.fetch("introspection_endpoint"), token: tokens.fetch("access_token"))
    info["active"] == true && info["sub"] == subject && info["client_id"] == HomebaseSettings.client_id
  end
  def logout_url(tokens)
    metadata.fetch("end_session_endpoint") + "?" + URI.encode_www_form(id_token_hint: tokens.fetch("id_token"), post_logout_redirect_uri: HomebaseSettings.origin + "/session/new")
  end
  private
  def pack(token, previous = {})
    { "access_token"=>token.fetch("access_token"), "refresh_token"=>token["refresh_token"] || previous["refresh_token"],
     "id_token"=>token["id_token"] || previous["id_token"], "expires_at"=>(Time.now.to_f * 1000).to_i + (token["expires_in"] || 300).to_i * 1000 }
  end
  def request_json(address, form = nil)
    uri = URI(address)
    req = form ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
    if form
      req.basic_auth(HomebaseSettings.client_id, ENV.fetch("OIDC_CLIENT_SECRET"))
      req.set_form_data(form)
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(req) }
    if !response.is_a?(Net::HTTPSuccess)
      if form && form[:grant_type] == "refresh_token" && response.code == "400"
        body = JSON.parse(response.body) rescue {}
        raise ExpiredGrant if body["error"] == "invalid_grant"
      end
      raise InvalidIdentity
    end
    JSON.parse(response.body)
  end
end
