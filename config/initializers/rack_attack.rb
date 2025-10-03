# Rate limiting and throttling configuration for HIPAA security
# Prevents brute force attacks, DDoS, and API abuse

class Rack::Attack
  # Use Redis as the cache store for tracking requests
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisStore.new(
    host: ENV.fetch('REDIS_HOST', 'localhost'),
    port: ENV.fetch('REDIS_PORT', 6379),
    db: 2, # Separate database for rate limiting
    namespace: 'rack_attack'
  )

  ### Configure allowlists and blocklists ###

  # Allow requests from localhost (for development)
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1' if Rails.env.development?
  end

  # Block suspicious requests
  blocklist('block-suspicious-requests') do |req|
    # Block requests with SQL injection attempts
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      req.path.include?('--') || req.path.include?("'") || req.path.include?(';')
    end
  end

  ### Throttle rules ###

  # Throttle login attempts per email
  # Allows 5 login attempts per email per 20 seconds
  throttle('login/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/auth/login' && req.post?
      # Extract email from params
      req.params.dig('user', 'email')&.downcase
    end
  end

  # Throttle login attempts per IP
  # Allows 10 login attempts per IP per minute
  throttle('login/ip', limit: 10, period: 1.minute) do |req|
    if req.path == '/api/auth/login' && req.post?
      req.ip
    end
  end

  # Throttle general API requests per IP
  # Allows 300 requests per IP per 5 minutes (1 req/second average)
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Throttle requests per authenticated user
  # Allows 1000 requests per user per 10 minutes
  throttle('api/user', limit: 1000, period: 10.minutes) do |req|
    if req.env['warden']&.user
      req.env['warden'].user.id
    end
  end

  ### Custom response for throttled requests ###
  self.throttled_responder = lambda do |env|
    retry_after = env['rack.attack.match_data'][:period]

    # Log security event
    if env['warden']&.user
      AuditLog.log_action(
        user: env['warden'].user,
        action: AuditLog::ACTIONS[:security_event],
        ip_address: env['REMOTE_ADDR'],
        user_agent: env['HTTP_USER_AGENT'],
        metadata: {
          event: 'rate_limit_exceeded',
          path: env['PATH_INFO'],
          retry_after: retry_after
        }
      ) rescue nil
    end

    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{
        error: 'Too many requests',
        message: 'Rate limit exceeded. Please try again later.',
        retry_after: retry_after
      }.to_json]
    ]
  end

  ### Logging ###
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]

    if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
      Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type']} #{req.ip} #{req.path}"
    end
  end
end
