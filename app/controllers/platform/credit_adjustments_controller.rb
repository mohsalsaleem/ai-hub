module Platform
  class CreditAdjustmentsController < BaseController
    def create
      organization = Organization.find(params[:organization_id])
      CreditAdjuster.post!(organization:, amount: params[:amount],
        reason: params[:reason], operator: current_platform_operator, request_ip: request.remote_ip)
      redirect_to platform_root_path(anchor: "organization-#{organization.id}"), notice: "Credit balance adjusted."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to platform_root_path(anchor: "organization-#{params[:organization_id]}"), alert: e.message
    end
  end
end
