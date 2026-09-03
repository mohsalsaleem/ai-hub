Rails.application.routes.draw do
  resource :registration, only: %i[new create]
  resource :session, only: %i[new create destroy]
  resource :organization, only: %i[new create show update]
  resources :applications, controller: "hub_applications", only: %i[index show new create] do
    post :rotate_token, on: :member
    patch :revoke, on: :member
    resources :task_definitions, only: %i[new create]
  end
  resources :task_definitions, only: %i[index show]
  resources :jobs, only: %i[index show]
  resources :workers, only: %i[index create destroy] do
    post :rotate_token, on: :member
  end
  get "dashboard", to: "dashboard#show", as: :dashboard
  get "docs", to: "docs#show", as: :docs
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "landing#show"

  namespace :api do
    namespace :v1 do
      resources :task_definitions, only: [ :index, :create ]
      resources :jobs, only: [ :create, :show ]

      namespace :worker do
        post "enroll", to: "enrollments#create"
        post "claims", to: "claims#create"
        get "task_definitions/:digest", to: "task_definitions#show", as: :task_definition
        post "jobs/:job_id/renew", to: "jobs#renew", as: :job_renew
        post "jobs/:job_id/complete", to: "jobs#complete", as: :job_complete
        post "jobs/:job_id/fail", to: "jobs#fail", as: :job_fail
        post "metrics", to: "metrics#create"
      end
    end
  end

  namespace :openai, path: nil do
    namespace :v1, path: "v1" do
      get "models", to: "models#index"
      post "responses", to: "responses#create"
      get "responses/:id", to: "responses#show"
      post "chat/completions", to: "chat_completions#create"
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
