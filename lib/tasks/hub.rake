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
end
