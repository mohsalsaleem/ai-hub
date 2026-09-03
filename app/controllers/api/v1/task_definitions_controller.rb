module Api
  module V1
    class TaskDefinitionsController < ApplicationController
      MAX_SCHEMA_BYTES = 32.kilobytes

      def index
        render json: { definitions: hub_application.task_definitions.order(:key, :version).map { |definition| definition_json(definition) } }
      end

      def create
        if request.content_length.to_i > 96.kilobytes
          return render json: { error: "definition_too_large" }, status: :content_too_large
        end

        definition = hub_application.task_definitions.new(definition_params)
        definition.save!
        render json: definition_json(definition), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: "invalid_definition", details: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def definition_params
        params.require(:task_definition).permit(:key, :version, :executor, :instructions,
          input_schema: {}, output_schema: {}, requirements: {})
      end

      def definition_json(definition)
        { key: definition.key, version: definition.version, reference: definition.reference,
          digest: definition.digest, executor: definition.executor, requirements: definition.requirements }
      end
    end
  end
end
