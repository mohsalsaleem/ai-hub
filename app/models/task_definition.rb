class TaskDefinition < ApplicationRecord
  EXECUTORS = %w[structured_generation].freeze
  KEY_FORMAT = /\A[a-z][a-z0-9_.-]{2,99}\z/

  belongs_to :hub_application
  has_many :jobs, dependent: :restrict_with_error

  validates :key, presence: true, format: { with: KEY_FORMAT }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :executor, inclusion: { in: EXECUTORS }
  validates :instructions, presence: true, length: { maximum: 20_000 }
  validates :digest, presence: true
  validates :version, uniqueness: { scope: [ :hub_application_id, :key ] }
  validate :schemas_are_valid

  before_validation :assign_digest, on: :create

  def reference = "#{key}@#{version}"

  private

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
