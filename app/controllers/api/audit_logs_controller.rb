module Api
  class AuditLogsController < ApplicationController
    include Authorizable

    before_action :authenticate_user!
    before_action :authorize_auditor_or_admin

    # GET /api/audit-logs
    def index
      @audit_logs = AuditLog.includes(:user).order(created_at: :desc)

      # Filtering
      @audit_logs = @audit_logs.where(user_id: params[:user_id]) if params[:user_id].present?
      @audit_logs = @audit_logs.where(action: params[:action_filter]) if params[:action_filter].present?
      @audit_logs = @audit_logs.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
      @audit_logs = @audit_logs.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

      # Manual pagination
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 50).to_i
      total_count = @audit_logs.count
      total_pages = (total_count.to_f / per_page).ceil

      @audit_logs = @audit_logs.offset((page - 1) * per_page).limit(per_page)

      render json: {
        status: { code: 200, message: 'Audit logs retrieved successfully' },
        data: {
          audit_logs: @audit_logs.map { |log| audit_log_json(log) },
          pagination: {
            current_page: page,
            total_pages: total_pages,
            total_count: total_count,
            per_page: per_page
          }
        }
      }
    end

    private

    def authorize_auditor_or_admin
      unless current_user.can_view_audit_logs?
        render json: {
          status: { code: 403, message: 'Forbidden. Insufficient permissions.' }
        }, status: :forbidden
      end
    end

    def audit_log_json(log)
      {
        id: log.id,
        action: log.action,
        user: log.user ? {
          id: log.user.id,
          email: log.user.email,
          full_name: log.user.full_name
        } : nil,
        resource_type: log.resource_type,
        resource_id: log.resource_id,
        ip_address: log.ip_address,
        user_agent: log.user_agent,
        metadata: log.metadata,
        created_at: log.created_at
      }
    end
  end
end
