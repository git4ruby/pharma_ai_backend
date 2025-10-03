# Redis configuration for sessions and caching
# Connects to Redis container from docker-compose.yml

REDIS_CONFIG = {
  host: ENV.fetch('REDIS_HOST', 'localhost'),
  port: ENV.fetch('REDIS_PORT', 6379),
  db: 0, # Database 0 for sessions
  connect_timeout: 5,
  reconnect_attempts: 3
}

# Initialize Redis connection
$redis = Redis.new(REDIS_CONFIG)

# Test connection on startup
begin
  $redis.ping
  Rails.logger.info "✅ Redis connected successfully at #{REDIS_CONFIG[:host]}:#{REDIS_CONFIG[:port]}"
rescue Redis::CannotConnectError => e
  Rails.logger.error "❌ Redis connection failed: #{e.message}"
  Rails.logger.warn "Sessions will not persist. Start Redis with: docker-compose up -d redis"
end
