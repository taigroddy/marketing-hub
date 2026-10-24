# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  get "up" => "rails/health#show", as: :rails_health_check

  # HTML Web Authentication Routes
  get    "login"                 => "sessions#new",         as: :login
  post   "login"                 => "sessions#create"
  delete "logout"                => "sessions#destroy",     as: :logout
  get    "logout"                => "sessions#destroy"

  get    "register"              => "registrations#new",    as: :register
  post   "register"              => "registrations#create"

  get    "confirm_email/:token"  => "confirmations#show",   as: :confirm_email
  get    "dashboard"             => "dashboard#show",       as: :dashboard

  resources :campaigns, only: [ :index, :show, :new, :create, :edit, :update ]

  root to: "sessions#new"

  # OAuth Platform Accounts routes (Direct v1 pattern)
  get "oauth/:platform/callback" => "api/v1/platform_accounts#callback", constraints: { platform: /(facebook|google)/ }

  scope "v1/:platform", constraints: { platform: /(facebook|google)/ } do
    get  "oauth/authorize" => "api/v1/platform_accounts#authorize", as: :platform_oauth_authorize
    get  "oauth/callback"  => "api/v1/platform_accounts#callback",  as: :platform_oauth_callback
    post "oauth/callback"  => "api/v1/platform_accounts#callback"
    post "campaigns/:id/publish" => "api/v1/platform_campaigns#publish", as: :platform_campaign_publish
    post "campaigns/:id/resync"  => "api/v1/platform_campaigns#resync",  as: :platform_campaign_resync
  end

  # API v1 Authentication Routes
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post :register
        post :login
        post :refresh
        post :logout
        get  "confirm_email/:token", action: :confirm_email, as: :confirm_email
        post "confirm_email/:token", action: :confirm_email
        get  "confirm/:token",       action: :confirm_email, as: :confirm
        get  :me
      end

      resources :campaigns, only: [ :index, :show, :create, :update ]
      resources :platform_accounts, only: [ :index ]

      scope ":platform", constraints: { platform: /(facebook|google)/ } do
        get  "oauth/authorize" => "platform_accounts#authorize"
        get  "oauth/callback"  => "platform_accounts#callback"
        post "oauth/callback"  => "platform_accounts#callback"
        post "campaigns/:id/publish" => "platform_campaigns#publish"
        post "campaigns/:id/resync"  => "platform_campaigns#resync"
      end
    end
  end
end
