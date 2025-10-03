module Api
  class AuditLogsController < ApplicationController
    include Authorizable

    before_action :authenticate_user!
    before_action :authorize_auditor_or_admin

    # GET /api/audit-logs
    def index
      @audit_logs = AuditLog.includes(:user)
                            .order(created_at: :desc)
                            .page(params[:page] || 1)
                            .per(params[:per_page] || 50)

      # Filtering
      @audit_logs = @audit_logs.where(user_id: params[:user_id]) if params[:user_id].present?
      @audit_logs = @audit_logs.where(action: params[:action]) if params[:action].present?
      @audit_logs = @audit_logs.where('created_at >= ?', params[:start_date]) if params[:start_date].present?
      @audit_logs = @audit_logs.where('created_at <= ?', params[:end_date]) if params[:end_date].present?

      render json: {
        status: { code: 200, message: 'Audit logs retrieved successfully' },
        data: {
          audit_logs: @audit_logs.map { |log| audit_log_json(log) },
          pagination: {
            current_page: @audit_logs.current_page,
            total_pages: @audit_logs.total_pages,
            total_count: @audit_logs.total_count,
            per_page: @audit_logs.limit_value
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
