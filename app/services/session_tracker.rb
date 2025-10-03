# SessionTracker Service
# Manages user sessions in Redis for HIPAA compliance
#
# Features:
# - Track active sessions with expiration (15 minutes)
# - Monitor last activity timestamp
# - Allow admins to view active sessions
# - Force logout (revoke sessions)
#
# Usage:
#   SessionTracker.track_session(user, token)
#   SessionTracker.update_activity(user_id)
#   SessionTracker.active_sessions
#   SessionTracker.revoke_session(user_id)

class SessionTracker
  SESSION_TIMEOUT = ENV.fetch('SESSION_TIMEOUT_MINUTES', 15).to_i.minutes

  class << self
    # Track a new session when user logs in
    # Stores: user_id, email, role, login_time, last_activity, ip_address
    def track_session(user, token, ip_address = nil)
      session_data = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        login_time: Time.current.to_i,
        last_activity: Time.current.to_i,
        ip_address: ip_address,
        token: token
      }

      redis.setex(
        session_key(user.id),
        SESSION_TIMEOUT.to_i,
        session_data.to_json
      )

      Rails.logger.info "Session tracked for user #{user.id} (#{user.email})"
    end

    # Update last activity timestamp (called on each API request)
    # This extends the session timeout
    def update_activity(user_id)
      session_data = get_session(user_id)
      return unless session_data

      session_data['last_activity'] = Time.current.to_i

      redis.setex(
        session_key(user_id),
        SESSION_TIMEOUT.to_i,
        session_data.to_json
      )
    end

    # Get session data for a specific user
    def get_session(user_id)
      data = redis.get(session_key(user_id))
      data ? JSON.parse(data) : nil
    end

    # Check if user has an active session
    def active?(user_id)
      redis.exists?(session_key(user_id))
    end

    # Get all active sessions (admin only)
    # Returns array of session data
    def active_sessions
      keys = redis.keys("session:*")
      sessions = []

      keys.each do |key|
        data = redis.get(key)
        sessions << JSON.parse(data) if data
      end

      sessions.sort_by { |s| -s['last_activity'] }
    end

    # Count of active sessions
    def active_count
      redis.keys("session:*").count
    end

    # Revoke a session (force logout)
    def revoke_session(user_id)
      result = redis.del(session_key(user_id))
      Rails.logger.info "Session revoked for user #{user_id}"
      result > 0
    end

    # Revoke all sessions for a user (useful when password changes)
    def revoke_all_sessions(user_id)
      revoke_session(user_id)
    end

    # Get session duration in seconds
    def session_duration(user_id)
      session_data = get_session(user_id)
      return 0 unless session_data

      Time.current.to_i - session_data['login_time']
    end

    # Get time since last activity in seconds
    def time_since_activity(user_id)
      session_data = get_session(user_id)
      return nil unless session_data

      Time.current.to_i - session_data['last_activity']
    end

    # Check if session is about to expire (within 2 minutes)
    def expiring_soon?(user_id)
      ttl = redis.ttl(session_key(user_id))
      ttl > 0 && ttl < 120 # Less than 2 minutes
    end

    # Cleanup expired sessions (called by background job)
    def cleanup_expired_sessions
      # Redis automatically removes expired keys, but we can log them
      count = active_count
      Rails.logger.info "Active sessions: #{count}"
      count
    end

    private

    def redis
      @redis ||= Redis.new(
        host: ENV.fetch('REDIS_HOST', 'localhost'),
        port: ENV.fetch('REDIS_PORT', 6379),
        db: ENV.fetch('REDIS_DB', 0)
      )
    end

    def session_key(user_id)
      "session:#{user_id}"
    end
  end
end
