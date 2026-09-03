module Api
  module V1
    module Worker
      class MetricsController < BaseController
        MAX_SERIES = 152

        def create
          return render(json: { error: "payload_too_large" }, status: :content_too_large) if request.content_length.to_i > 64.kilobytes

          current_worker.update_columns(latest_metrics: normalized_metrics, metrics_reported_at: Time.current)
          render json: { status: "recorded" }
        end

        private

        def normalized_metrics
          series = Array(params[:series]).first(MAX_SERIES).filter_map do |row|
            next unless row.is_a?(ActionController::Parameters)

            value = Float(row[:value], exception: false)
            next unless value&.finite?

            labels = row[:labels].is_a?(ActionController::Parameters) ? row[:labels].to_unsafe_h : {}
            { name: row[:name].to_s.first(100), type: row[:type].to_s.first(20), value:,
              labels: labels.first(6).to_h { |key, label| [ key.to_s.first(50), label.to_s.byteslice(0, 64) ] } }
          end
          { schema_version: params[:schema_version].to_i, observed_at: params[:observed_at].to_s.first(40), series: }
        end
      end
    end
  end
end
