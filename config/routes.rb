Rails.application.routes.draw do
  # Devise routes for API
  devise_for :users, path: 'api/auth', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    registration: 'signup'
  }, controllers: {
    sessions: 'api/auth/sessions',
    registrations: 'api/auth/registrations'
  }

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
