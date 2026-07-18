Rails.application.routes.draw do
  resource  :session
  resource  :registration, only: %i[new create]
  resources :passwords, param: :token

  get "auth/google_oauth2/callback", to: "sessions/omniauth#create"
  get "auth/failure",                to: "sessions/omniauth#failure"
  resource :google_registration,   only: %i[new create]
  resource :two_factor,            only: %i[new create destroy]
  resource :two_factor_challenge,  only: %i[new create]

  get "privacy", to: "pages#privacy", as: :privacy

  namespace :stripe do
    resources :webhooks, only: :create
  end

  resources :conversations, only: :show do
    resources :messages, only: :create
  end

  resources :homologation_requests, only: %i[index new create show edit update] do
    resource  :submission, only: :create, controller: "homologation_request_submissions"
    resource  :checkout,   only: :create, controller: "homologation_request_checkouts"
    resources :documents,  only: %i[show create destroy], controller: "homologation_request_documents"
  end

  resource :profile, only: %i[show edit update] do
    get :export
  end
  resource :profile_deletion, only: :create, controller: "profile_deletions"
  resources :notifications, only: %i[index show] do
    post :read_all, on: :collection
  end
  resource  :locale, only: :update
  resource  :push_subscription, only: %i[create destroy]

  namespace :admin do
    resource :pipeline, only: :show
    resources :staff_members, only: %i[new create]

    resources :homologation_requests, only: :show do
      scope module: :homologation_requests do
        resource  :pipeline_advance,     only: :create
        resource  :pipeline_retreat,     only: :create
        resources :status_transitions,   only: :create
        resource  :payment_confirmation,  only: :create
        resource  :document_request,     only: :create
        resource  :document_checklist,   only: :update
        resource  :conversation,         only: :create
        resource  :archive,              only: :show
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up"       => "rails/health#show",     as: :rails_health_check
  get "up/db"    => "health_checks#db",       as: :db_health_check
  get "up/queue" => "health_checks#queue",    as: :queue_health_check

  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root to: "pages#home"
end
