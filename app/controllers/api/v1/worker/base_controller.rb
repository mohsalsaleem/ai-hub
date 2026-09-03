module Api
  module V1
    module Worker
      class BaseController < ActionController::API
        before_action :authenticate_worker!

        private

        attr_reader :current_worker

        def authenticate_worker!
          bearer = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
          @current_worker = ::Worker.authenticate(bearer)
          return render json: { error: "invalid_worker_token" }, status: :unauthorized unless @current_worker

          @current_worker.seen!(reported_id: request.headers["X-Worker-Id"],
            version: request.headers["X-Worker-Version"], capabilities: request.headers["X-Worker-Capabilities"].to_s.split(","))
        end
      end
    end
  end
end
