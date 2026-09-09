class HomebaseSettings
  def self.mode
    value = ENV.fetch("HOMEBASE_AUTH_MODE", "off")
    raise "Invalid HOMEBASE_AUTH_MODE" unless %w[off linking].include?(value)
    value
  end
  def self.enabled? = mode != "off"
  def self.issuer = ENV.fetch("OIDC_ISSUER")
  def self.client_id = ENV.fetch("OIDC_CLIENT_ID", "aihub")
  def self.origin = ENV.fetch("PUBLIC_URL").delete_suffix("/")
  def self.local? = !Rails.env.production? && ENV["HOMEBASE_ALLOW_LOCAL_HTTP"] == "true"
  def self.validate!
    return unless enabled?
    %w[OIDC_ISSUER OIDC_CLIENT_SECRET PUBLIC_URL HOMEBASE_URL HOMEBASE_APP_KEY].each { |key| ENV.fetch(key).presence || raise("Missing #{key}") }
    [ issuer, origin, ENV.fetch("HOMEBASE_URL") ].each do |value|
      uri = URI(value)
      local = local? && %w[localhost 127.0.0.1].include?(uri.host)
      raise "Homebase requires HTTPS" unless (uri.scheme == "https" || (local && uri.scheme == "http")) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
    end
  end
  def self.safe_path(value, fallback = "/dashboard")
    value.is_a?(String) && value.start_with?("/") && !value.start_with?("//") && !value.match?(/[\\\x00-\x20\x7f]/) ? value : fallback
  end
end
