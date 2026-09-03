Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"

  namespace :api do
    namespace :v1 do
      resources :task_definitions, only: [ :index, :create ]
      resources :jobs, only: [ :create, :show ]

      namespace :worker do
        post "claims", to: "claims#create"
        get "task_definitions/:digest", to: "task_definitions#show", as: :task_definition
        post "jobs/:job_id/renew", to: "jobs#renew", as: :job_renew
        post "jobs/:job_id/complete", to: "jobs#complete", as: :job_complete
        post "jobs/:job_id/fail", to: "jobs#fail", as: :job_fail
        post "metrics", to: "metrics#create"
      end
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
