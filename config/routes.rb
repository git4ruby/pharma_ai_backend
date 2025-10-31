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

    # Admin routes
    namespace :admin do
      # Background jobs monitoring
      get 'background_jobs/stats', to: 'background_jobs#stats'
      get 'background_jobs/queues', to: 'background_jobs#queues'
      get 'background_jobs/failed', to: 'background_jobs#failed_jobs'
      get 'background_jobs/document_stats', to: 'background_jobs#document_processing_stats'
      post 'background_jobs/:jid/retry', to: 'background_jobs#retry_job'
      delete 'background_jobs/:jid', to: 'background_jobs#delete_job'

      # S3 management
      post 's3/import', to: 's3#import'
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
