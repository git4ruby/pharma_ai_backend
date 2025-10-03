module Api
  module Auth
    class SessionsController < Devise::SessionsController
      respond_to :json

      # Override create to track session
      def create
        super do |resource|
          # Get JWT token from response header
          token = response.headers['Authorization']

          # Track session in Redis
          SessionTracker.track_session(
            resource,
            token,
            request.remote_ip
          )

          # Log successful login
          AuditLog.log_action(
            user: resource,
            action: AuditLog::ACTIONS[:login],
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            metadata: {
              email: resource.email,
              role: resource.role
            }
          )
        end
      end

      # Override destroy to revoke session
      def destroy
        if current_user
          # Log logout before destroying session
          AuditLog.log_action(
            user: current_user,
            action: AuditLog::ACTIONS[:logout],
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            metadata: {}
          )

          SessionTracker.revoke_session(current_user.id)
        end
        super
      end

      # Handle failed login attempts
      def respond_to_unauthenticated
        # Try to find user by email for audit logging
        email = params.dig(:user, :email)
        user = User.find_by(email: email) if email.present?

        # Log failed login attempt (even if user doesn't exist for security monitoring)
        if user
          AuditLog.log_action(
            user: user,
            action: AuditLog::ACTIONS[:failed_login],
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            metadata: { email: email, reason: 'invalid_credentials' }
          )
        end

        render json: {
          status: { code: 401, message: 'Invalid email or password.' }
        }, status: :unauthorized
      end

      private

      def respond_with(resource, _opts = {})
        render json: {
          status: { code: 200, message: 'Logged in successfully.' },
          data: {
            user: UserSerializer.new(resource).serializable_hash[:data][:attributes],
            session: {
              timeout_minutes: ENV.fetch('SESSION_TIMEOUT_MINUTES', 15).to_i,
              expires_at: (Time.current + ENV.fetch('SESSION_TIMEOUT_MINUTES', 15).to_i.minutes).iso8601
            }
          }
        }, status: :ok
      end

      def respond_to_on_destroy
        if current_user
          render json: {
            status: { code: 200, message: 'Logged out successfully.' }
          }, status: :ok
        else
          render json: {
            status: { code: 401, message: 'No active session.' }
          }, status: :unauthorized
        end
      end
    end
  end
end
