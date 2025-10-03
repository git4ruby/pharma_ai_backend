# API Sessions Controller
# Manage and monitor active user sessions (Admin only)
#
# Endpoints:
# - GET /api/sessions - List all active sessions
# - GET /api/sessions/:user_id - Get specific user's session
# - DELETE /api/sessions/:user_id - Force logout a user

module Api
  class SessionsController < ApplicationController
    include Authorizable

    before_action :authenticate_user!
    before_action :authorize_admin, only: [:index, :destroy]

    # GET /api/sessions
    # List all active sessions (admin only)
    def index
      sessions = SessionTracker.active_sessions

      render json: {
        status: { code: 200, message: 'Active sessions retrieved.' },
        data: {
          total_sessions: sessions.count,
          sessions: sessions.map { |s| format_session(s) }
        }
      }, status: :ok
    end

    # GET /api/sessions/current
    # Get current user's session info
    def current
      session_data = SessionTracker.get_session(current_user.id)

      if session_data
        render json: {
          status: { code: 200, message: 'Session retrieved.' },
          data: {
            session: format_session(session_data),
            expiring_soon: SessionTracker.expiring_soon?(current_user.id)
          }
        }, status: :ok
      else
        render json: {
          status: { code: 404, message: 'No active session found.' }
        }, status: :not_found
      end
    end

    # DELETE /api/sessions/:user_id
    # Force logout a user (admin only)
    def destroy
      user_id = params[:id]

      if SessionTracker.revoke_session(user_id)
        render json: {
          status: { code: 200, message: 'Session revoked successfully.' }
        }, status: :ok
      else
        render json: {
          status: { code: 404, message: 'No active session found for this user.' }
        }, status: :not_found
      end
    end

    private

    def format_session(session_data)
      {
        user_id: session_data['user_id'],
        email: session_data['email'],
        role: session_data['role'],
        ip_address: session_data['ip_address'],
        login_time: Time.at(session_data['login_time']).iso8601,
        last_activity: Time.at(session_data['last_activity']).iso8601,
        duration_minutes: ((Time.current.to_i - session_data['login_time']) / 60.0).round(1),
        idle_minutes: ((Time.current.to_i - session_data['last_activity']) / 60.0).round(1)
      }
    end
  end
end
