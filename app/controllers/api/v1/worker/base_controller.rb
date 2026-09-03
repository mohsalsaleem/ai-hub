module Api
  module V1
    module Worker
      class BaseController < ActionController::API
        before_action :authenticate_worker!

        private

        attr_reader :current_worker

        def authenticate_worker!
          @current_worker = if request.headers["X-Worker-Key-Id"].present?
            WorkerRequestSignature.new(request).authenticate!
          else
            authenticate_legacy_worker
          end
          return render json: { error: "invalid_worker_identity" }, status: :unauthorized unless @current_worker

          @current_worker.seen!(reported_id: request.headers["X-Worker-Id"],
            version: request.headers["X-Worker-Version"], capabilities: request.headers["X-Worker-Capabilities"].to_s.split(","))
        rescue WorkerRequestSignature::Replay => e
          render json: { error: e.message }, status: :conflict
        rescue WorkerRequestSignature::Error
          render json: { error: "invalid_worker_identity" }, status: :unauthorized
        end

        def authenticate_legacy_worker
          bearer = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
          worker = ::Worker.authenticate(bearer)
          worker unless worker&.enrolled?
        end
      end
    end
  end
end
