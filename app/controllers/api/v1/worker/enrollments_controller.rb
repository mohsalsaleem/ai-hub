require "base64"

module Api
  module V1
    module Worker
      class EnrollmentsController < ActionController::API
        CHALLENGE_PREFIX = "aihub-worker-enrollment/v1\n"

        def create
          worker = ::Worker.authenticate(bearer)
          return render json: { error: "invalid_enrollment_token" }, status: :unauthorized unless worker

          public_key_pem = params.require(:public_key).to_s
          proof_encoded = params.require(:proof).to_s
          if public_key_pem.bytesize > 4.kilobytes || proof_encoded.bytesize > 1.kilobyte
            return render json: { error: "invalid_enrollment_request" }, status: :unprocessable_entity
          end

          public_key = OpenSSL::PKey.read(public_key_pem)
          return render json: { error: "unsupported_key_type" }, status: :unprocessable_entity unless public_key.oid == "ED25519"

          fingerprint = OpenSSL::Digest::SHA256.hexdigest(public_key.public_to_der)
          proof = Base64.strict_decode64(proof_encoded)
          challenge = "#{CHALLENGE_PREFIX}#{fingerprint}"
          return render json: { error: "invalid_key_proof" }, status: :unprocessable_entity unless public_key.verify(nil, proof, challenge)

          if worker.enrolled? && worker.key_fingerprint != fingerprint
            return render json: { error: "identity_already_enrolled" }, status: :conflict
          end

          worker.update!(public_key_pem: public_key.public_to_pem, key_fingerprint: fingerprint,
            enrolled_at: worker.enrolled_at || Time.current)
          render json: { worker_id: worker.id, key_fingerprint: fingerprint, enrolled_at: worker.enrolled_at }
        rescue ActionController::ParameterMissing, ArgumentError, OpenSSL::PKey::PKeyError
          render json: { error: "invalid_enrollment_request" }, status: :unprocessable_entity
        end

        private

        def bearer = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
      end
    end
  end
end
