class TaskDefinitionsController < ApplicationController
  before_action :require_owner!, only: %i[new create]

  def index
    @definitions = current_organization.task_definitions.includes(:hub_application)
      .order(key: :asc, version: :desc)
  end

  def show
    @definition = current_organization.task_definitions.includes(:hub_application).find(params[:id])
  end

  def new
    @application = current_organization.hub_applications.find(params[:application_id])
    @definition = @application.task_definitions.new(version: 1, executor: "structured_generation",
      input_schema: default_schema, output_schema: default_schema)
  end

  def create
    @application = current_organization.hub_applications.find(params[:application_id])
    @definition = @application.task_definitions.new(definition_params.except(:input_schema, :output_schema))
    @definition.input_schema = parse_schema(:input_schema)
    @definition.output_schema = parse_schema(:output_schema)
    @definition.save!
    redirect_to task_definition_path(@definition), notice: "#{@definition.reference} published."
  rescue JSON::ParserError => e
    @definition ||= @application.task_definitions.new(definition_params.except(:input_schema, :output_schema))
    @definition.errors.add(:base, "Schemas must contain valid JSON: #{e.message}")
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def definition_params
    params.require(:task_definition).permit(:key, :version, :executor, :instructions,
      :input_schema, :output_schema)
  end

  def parse_schema(key) = JSON.parse(definition_params.fetch(key))
  def default_schema = { type: "object", additionalProperties: false, properties: {} }
end
