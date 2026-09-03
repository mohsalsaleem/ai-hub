module Openai
  module V1
    class ModelsController < BaseController
      def index
        definitions = hub_application.task_definitions.where(executor: "chat_completion", active: true).order(:key, :version)
        render json: { object: "list", data: definitions.map { |definition|
          { id: definition.reference, object: "model", created: definition.created_at.to_i,
            owned_by: hub_application.slug }
        } }
      end
    end
  end
end
