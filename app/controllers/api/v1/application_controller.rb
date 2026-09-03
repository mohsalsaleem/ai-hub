module Api
  module V1
    class ApplicationController < ActionController::API
      before_action :authenticate_application!

      private

      attr_reader :hub_application

      def authenticate_application!
        @hub_application = HubApplication.authenticate(bearer_token)
        render json: { error: "invalid_application_token" }, status: :unauthorized unless @hub_application
      end

      def bearer_token = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
    end
  end
end
