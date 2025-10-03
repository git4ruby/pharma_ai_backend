Devise.setup do |config|
  config.jwt do |jwt|
    jwt.secret = ENV.fetch('JWT_SECRET_KEY', Rails.application.credentials.secret_key_base)
    jwt.dispatch_requests = [
      ['POST', %r{^/api/auth/login$}]
    ]
    jwt.revocation_requests = [
      ['DELETE', %r{^/api/auth/logout$}]
    ]
    jwt.expiration_time = (ENV.fetch('JWT_EXPIRATION_HOURS', 24).to_i).hours.to_i
  end

  # Session timeout for HIPAA compliance (15 minutes of inactivity)
  config.timeout_in = ENV.fetch('SESSION_TIMEOUT_MINUTES', 15).to_i.minutes

  # Lock account after failed attempts
  config.maximum_attempts = 5
  config.unlock_strategy = :time
  config.unlock_in = 1.hour

  # Password length for HIPAA compliance
  config.password_length = 12..128

  # Skip session storage for API
  config.skip_session_storage = [:http_auth, :params_auth]

  # Navigational formats (empty for API-only)
  config.navigational_formats = []
end
