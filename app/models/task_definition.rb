class TaskDefinition < ApplicationRecord
  EXECUTORS = %w[structured_generation chat_completion].freeze
  KEY_FORMAT = /\A[a-z][a-z0-9_.-]{2,99}\z/
  CHAT_INPUT_SCHEMA = {
    type: "object", additionalProperties: false, required: [ "messages" ],
    properties: {
      messages: { type: "array", minItems: 1, items: {
        type: "object", additionalProperties: false, required: %w[role content],
        properties: {
          role: { type: "string", enum: %w[system developer user assistant] },
          content: { type: "string" }
        }
      } },
      temperature: { type: "number", minimum: 0, maximum: 2 },
      top_p: { type: "number", minimum: 0, maximum: 1 },
      max_tokens: { type: "integer", minimum: 1 },
      stop: { type: [ "string", "array" ], items: { type: "string" } }
    }
  }.freeze
  CHAT_OUTPUT_SCHEMA = {
    type: "object", additionalProperties: false, required: %w[content finish_reason usage],
    properties: {
      content: { type: "string" }, finish_reason: { type: [ "string", "null" ] },
      usage: { type: "object" }
    }
  }.freeze

  belongs_to :hub_application
  has_many :jobs, dependent: :restrict_with_error

  validates :key, presence: true, format: { with: KEY_FORMAT }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :executor, inclusion: { in: EXECUTORS }
  validates :instructions, presence: true, length: { maximum: 20_000 }
  validates :digest, presence: true
  validates :version, uniqueness: { scope: [ :hub_application_id, :key ] }
  validate :schemas_are_valid

  before_validation :assign_executor_schemas, on: :create
  before_validation :assign_digest, on: :create

  def reference = "#{key}@#{version}"

  private

  def assign_executor_schemas
    return unless executor == "chat_completion"

    self.input_schema = CHAT_INPUT_SCHEMA.deep_dup if input_schema.blank?
    self.output_schema = CHAT_OUTPUT_SCHEMA.deep_dup if output_schema.blank?
  end

  def assign_digest
    payload = attributes.slice("key", "version", "executor", "instructions", "input_schema", "output_schema", "requirements")
    self.digest = OpenSSL::Digest::SHA256.hexdigest(JSON.generate(payload.deep_sort))
  end

  def schemas_are_valid
    JSONSchemer.schema(input_schema)
    JSONSchemer.schema(output_schema)
  rescue StandardError => e
    errors.add(:base, "invalid JSON Schema: #{e.message}")
  end
end
