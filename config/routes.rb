# frozen_string_literal: true

Rails.application.routes.draw do
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

  # API v1 Authentication Routes
  namespace :api do
    namespace :v1 do
      namespace :auth do
        post :register
        post :login
        get  "confirm_email/:token", action: :confirm_email, as: :confirm_email
        post "confirm_email/:token", action: :confirm_email
        get  :me
      end

      resources :campaigns, only: [ :index, :show, :create, :update ]
    end
  end
end
