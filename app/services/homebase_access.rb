require "net/http"
class HomebaseAccess
  class Denied < StandardError; end
  class Unavailable < StandardError; end
  def self.check!(issuer, subject)
    HomebaseSettings.validate!
    raise Denied unless issuer == HomebaseSettings.issuer && subject.present?
    uri = URI.join(ENV.fetch("HOMEBASE_URL"), "/api/access/check")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('HOMEBASE_APP_KEY')}"
    request["Content-Type"] = "application/json"
    request.body = { issuer: issuer, subject: subject }.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 5) { |http| http.request(request) }
    raise Unavailable unless response.is_a?(Net::HTTPSuccess)
    result = JSON.parse(response.body)
    raise Denied unless result["appId"] == "aihub" && result["allowed"] == true
    true
  rescue Denied, Unavailable
    raise
  rescue StandardError
    raise Unavailable
  end
end
