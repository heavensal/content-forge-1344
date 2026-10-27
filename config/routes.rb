Rails.application.routes.draw do
  use_doorkeeper do |oauth|
    oauth.controllers authorizations: "mcp/oauth_authorizations", tokens: "mcp/oauth_tokens"
    oauth.skip_controllers :applications, :authorized_applications, :token_info
  end
  get "/.well-known/oauth-protected-resource", to: "mcp/metadata#show"
  get "/.well-known/oauth-protected-resource/mcp", to: "mcp/metadata#show"
  get "/mcp", to: "mcp/server#show"
  post "/mcp", to: "mcp/server#create"
  namespace :mcp do
    resources :changes, only: %i[show update]
  end
  get "/.well-known/oauth-authorization-server", to: "mcp/oauth_metadata#show"
  post "/oauth/register", to: "mcp/oauth_clients#create"
  get "/settings/integrations/mcp", to: "mcp/authorizations#index", as: :settings_mcp_authorizations
  delete "/settings/integrations/mcp", to: "mcp/authorizations#destroy", as: :mcp_authorization

  devise_for :users
  patch "locale", to: "locales#update", as: :locale
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :articles, only: [ :index, :show ], param: :slug
      resources :faqs, only: [ :index ]
      resources :reviews, only: [ :index ]
      post "send_form", to: "send_form#create", as: :send_form
    end
  end

  namespace :admin do
    %w[users websites website_memberships articles faqs reviews mcp_changes].each do |entity|
      resources entity, only: %i[index show], controller: "records", defaults: { entity: entity }
    end
  end

  resources :websites do
    resources :memberships, only: %i[create destroy], controller: "website_memberships"
    resource :contact_form_integration, only: [ :show ], controller: "contact_form_integrations"
    resources :articles
    resources :article_images, only: [ :create ]
    resources :faqs
    resources :reviews
  end

  root "websites#index"
end
