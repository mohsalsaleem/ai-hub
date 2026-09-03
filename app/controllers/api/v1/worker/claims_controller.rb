module Api
  module V1
    module Worker
      class ClaimsController < BaseController
        def create
          deadline = params.fetch(:wait_seconds, 0).to_i.clamp(0, 20).seconds.from_now
          claimed = nil
          loop do
            claimed = JobClaimer.new(current_worker).claim
            break if claimed || Time.current >= deadline
            sleep 0.5
          end

          return render json: { job: nil } unless claimed

          job, lease_token = claimed
          render json: {
            lease_seconds: Job::LEASE_SECONDS,
            lease_token:,
            job: { id: job.public_id, task_digest: job.task_definition.digest,
                   task: job.task_definition.reference, input: job.input }
          }
        end
      end
    end
  end
end
