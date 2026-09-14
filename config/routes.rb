# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  namespace :api do
    get 'hello', to: 'hello#show'
    get 'roster', to: 'roster#index'
    post 'imports/preview', to: 'imports#preview'
    post 'imports/apply', to: 'imports#apply'
  end

  get 'hello', to: 'api/hello#show', constraints: lambda { |request|
    !request.format.html?
  }

  # Defines the root path route ("/")
  root 'spa#index'

  get '*path', to: 'spa#index', constraints: lambda { |request|
    request.format.html? && !request.path.start_with?('/api', '/rails', '/up')
  }
end
