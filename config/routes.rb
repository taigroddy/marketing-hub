# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  get "up" => "rails/health#show", as: :rails_health_check

  # HTML Web Authentication Routes
  get    "login"                 => "sessions#new",         as: :login
  delete "logout"                => "sessions#destroy",     as: :logout
  get    "logout"                => "sessions#destroy"

  get    "register"              => "registrations#new",    as: :register

  get    "confirm_email/:token"  => "confirmations#show",   as: :confirm_email
  get    "dashboard"             => "dashboard#show",       as: :dashboard

  resources :campaigns, only: [ :index, :show, :new, :edit ]

  root to: "sessions#new"

  # OAuth Platform Accounts redirect callback from external platform
  get "oauth/:platform/callback" => "api/v1/platform_accounts#callback", constraints: { platform: /(facebook|google)/ }

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
