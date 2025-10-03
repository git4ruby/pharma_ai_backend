Rails.application.routes.draw do
  # Devise routes for API
  devise_for :users, path: 'api/auth', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    registration: 'signup'
  }, controllers: {
    sessions: 'api/auth/sessions',
    registrations: 'api/auth/registrations',
    passwords: 'api/auth/passwords'
  }

  # API routes
  namespace :api do
    # User management (RBAC demo)
    resources :users, only: [:index, :destroy] do
      collection do
        get 'me'
      end
      member do
        patch 'role', to: 'users#update_role'
      end
    end

    # Session management (Redis-backed)
    resources :sessions, only: [:index, :destroy] do
      collection do
        get 'current'
      end
    end

    # Document management
    resources :documents, only: [:index, :show, :create, :destroy]

    # Query/Q&A endpoints
    resources :queries, only: [:index, :show, :create]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
