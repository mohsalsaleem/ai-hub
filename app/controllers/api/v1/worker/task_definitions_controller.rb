module Api
  module V1
    module Worker
      class TaskDefinitionsController < BaseController
        def show
          definition = TaskDefinition.joins(:jobs).where(digest: params[:digest], active: true,
            jobs: { worker_id: current_worker.id, status: "leased" })
            .where("jobs.leased_until > ?", Time.current).first!
          render json: {
            key: definition.key, version: definition.version, digest: definition.digest,
            executor: definition.executor, instructions: definition.instructions,
            input_schema: definition.input_schema, output_schema: definition.output_schema,
            requirements: definition.requirements
          }
        rescue ActiveRecord::RecordNotFound
          render json: { error: "unknown_task_definition" }, status: :not_found
        end
      end
    end
  end
end
