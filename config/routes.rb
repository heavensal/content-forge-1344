Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :articles, only: [ :index ]
      resources :faqs, only: [ :index ]
      resources :reviews, only: [ :index ]
    end
  end

  resources :websites do
    resources :articles
    resources :faqs
    resources :reviews
  end

  root "websites#index"
end
