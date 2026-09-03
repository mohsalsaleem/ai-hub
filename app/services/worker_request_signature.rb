require "base64"

class WorkerRequestSignature
  MAX_CLOCK_SKEW = 5.minutes
  NONCE_TTL = 10.minutes

  Error = Class.new(StandardError)
  Replay = Class.new(Error)

  def self.canonical(method:, path:, timestamp:, nonce:, body:)
    [ method.to_s.upcase, path, timestamp.to_s, nonce, OpenSSL::Digest::SHA256.hexdigest(body.to_s) ].join("\n")
  end

  def initialize(request)
    @request = request
  end

  def authenticate!
    worker = Worker.find_by!(key_fingerprint: header("X-Worker-Key-Id"), active: true)
    timestamp = Integer(header("X-Worker-Timestamp"), 10)
    nonce = header("X-Worker-Nonce")
    signature = Base64.strict_decode64(header("X-Worker-Signature"))

    raise Error, "stale_timestamp" if (Time.current.to_i - timestamp).abs > MAX_CLOCK_SKEW
    raise Error, "invalid_nonce" unless nonce.match?(/\A[0-9a-f]{32,128}\z/)

    message = self.class.canonical(method: @request.request_method, path: @request.fullpath,
      timestamp:, nonce:, body: @request.raw_post)
    public_key = OpenSSL::PKey.read(worker.public_key_pem)
    raise Error, "invalid_signature" unless public_key.verify(nil, signature, message)

    remember_nonce!(worker, nonce)
    worker
  rescue ActiveRecord::RecordNotFound, ArgumentError, OpenSSL::PKey::PKeyError
    raise Error, "invalid_worker_identity"
  end

  private

  def header(name)
    @request.headers[name].to_s.presence || raise(Error, "missing_signature_headers")
  end

  def remember_nonce!(worker, nonce)
    WorkerRequestNonce.where("expires_at < ?", Time.current).delete_all
    worker.worker_request_nonces.create!(nonce_digest: OpenSSL::Digest::SHA256.hexdigest(nonce),
      expires_at: NONCE_TTL.from_now)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    raise Replay, "replayed_request"
  end
end
