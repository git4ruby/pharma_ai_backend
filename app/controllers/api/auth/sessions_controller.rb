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
        end
      end

      # Override destroy to revoke session
      def destroy
        if current_user
          SessionTracker.revoke_session(current_user.id)
        end
        super
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
