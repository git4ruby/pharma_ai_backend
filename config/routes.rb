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
    resources :users, only: [:index, :create, :update, :destroy] do
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

    # Query audit (for admins/auditors)
    resources :query_audits, only: [:index], path: 'query-audits' do
      collection do
        get 'statistics'
      end
    end

    # Audit logs
    resources :audit_logs, only: [:index], path: 'audit-logs'

    # Compliance
    get 'compliance/status', to: 'compliance#status'

    # Analytics
    get 'analytics/dashboard', to: 'analytics#dashboard'
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
