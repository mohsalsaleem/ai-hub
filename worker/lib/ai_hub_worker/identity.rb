module AiHubWorker
  class Identity
    CHALLENGE_PREFIX = "aihub-worker-enrollment/v1\n"

    attr_reader :fingerprint

    def initialize(state_path)
      @path = File.join(state_path, "identity.pem")
      @enrollment_path = File.join(state_path, "identity.enrolled")
      FileUtils.mkdir_p(state_path, mode: 0o700)
      @key = load_or_create_key
      @fingerprint = OpenSSL::Digest::SHA256.hexdigest(@key.public_to_der)
    end

    def public_key_pem = @key.public_to_pem

    def enrollment_proof
      sign("#{CHALLENGE_PREFIX}#{fingerprint}")
    end

    def sign(message) = @key.sign(nil, message)

    def enrolled_with?(token)
      return false unless File.exist?(@enrollment_path)

      stored = File.binread(@enrollment_path)
      digest = token_digest(token)
      stored.bytesize == digest.bytesize && OpenSSL.fixed_length_secure_compare(stored, digest)
    end

    def mark_enrolled!(token)
      File.write(@enrollment_path, token_digest(token), mode: "w", perm: 0o600)
    end

    private

    def load_or_create_key
      return OpenSSL::PKey.read(File.binread(@path)) if File.exist?(@path)

      key = OpenSSL::PKey.generate_key("ED25519")
      temporary = "#{@path}.#{Process.pid}.tmp"
      File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(key.private_to_pem) }
      File.rename(temporary, @path)
      key
    ensure
      File.delete(temporary) if defined?(temporary) && temporary && File.exist?(temporary)
    end

    def token_digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end
end
