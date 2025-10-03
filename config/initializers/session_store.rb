# Session storage configuration using Redis
# For HIPAA compliance: sessions are encrypted and stored server-side

Rails.application.config.session_store :redis_store,
  servers: {
    host: ENV.fetch('REDIS_HOST', 'localhost'),
    port: ENV.fetch('REDIS_PORT', 6379),
    db: 1, # Use database 1 for sessions (separate from cache)
    namespace: 'pharma_ai_session'
  },
  expire_after: 15.minutes, # HIPAA requirement: automatic timeout
  key: '_pharma_ai_session',
  secure: Rails.env.production?, # HTTPS only in production
  httponly: true, # Prevent JavaScript access
  same_site: :strict # CSRF protection
