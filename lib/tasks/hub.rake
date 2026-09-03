namespace :hub do
  desc "Create an application and worker, printing each token once"
  task bootstrap: :environment do
    app_name = ENV.fetch("APP_NAME", "Example application")
    application, application_token = HubApplication.issue!(name: app_name,
      slug: ENV.fetch("APP_SLUG", app_name.parameterize))
    worker, worker_token = Worker.issue!(name: ENV.fetch("WORKER_NAME", "Local worker"))
    puts "Application: #{application.name}"
    puts "AI_HUB_APPLICATION_TOKEN=#{application_token}"
    puts "Worker: #{worker.name}"
    puts "AI_HUB_WORKER_TOKEN=#{worker_token}"
  end

  desc "Idempotently provision an application and worker from supplied tokens"
  task provision: :environment do
    application_token = ENV.fetch("AI_HUB_APPLICATION_TOKEN")
    worker_token = ENV.fetch("AI_HUB_WORKER_TOKEN")
    token_pattern = /\Aaih_[0-9a-f]{48}\z/
    raise "AI_HUB_APPLICATION_TOKEN must be a generated AI Hub token" unless application_token.match?(token_pattern)
    raise "AI_HUB_WORKER_TOKEN must be a generated AI Hub token" unless worker_token.match?(token_pattern)

    application = HubApplication.find_or_initialize_by(slug: ENV.fetch("APP_SLUG"))
    application.assign_attributes(
      name: ENV.fetch("APP_NAME"),
      token_digest: HubApplication.token_digest(application_token),
      active: true
    )
    application.save!

    worker = Worker.find_or_initialize_by(name: ENV.fetch("WORKER_NAME"))
    worker.assign_attributes(token_digest: Worker.token_digest(worker_token), active: true)
    worker.save!

    puts "Provisioned application #{application.slug} and worker #{worker.name}"
  end
end
