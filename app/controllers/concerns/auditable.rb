# Auditable concern for automatic action logging
# Include in controllers to automatically track all actions for HIPAA compliance

module Auditable
  extend ActiveSupport::Concern

  included do
    after_action :log_action, if: :current_user
  end

  private

  def log_action
    return if skip_audit_log?

    AuditLog.log_action(
      user: current_user,
      action: audit_action_name,
      resource: audit_resource,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: audit_metadata
    )
  rescue => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
    # Don't let audit logging failure break the request
  end

  # Determine the action name for the audit log
  def audit_action_name
    "#{controller_name}.#{action_name}"
  end

  # Override in controllers to specify the resource being acted upon
  def audit_resource
    nil
  end

  # Override in controllers to add custom metadata
  def audit_metadata
    {
      controller: controller_name,
      action: action_name,
      params: filtered_params
    }
  end

  # Filter out sensitive params
  def filtered_params
    params.except(:controller, :action, :password, :password_confirmation, :current_password).to_unsafe_h
  end

  # Override in controllers to skip audit logging for certain actions
  def skip_audit_log?
    false
  end

  # Helper method to log custom events
  def log_audit_event(action:, resource: nil, metadata: {})
    return unless current_user

    AuditLog.log_action(
      user: current_user,
      action: action,
      resource: resource,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      metadata: metadata.merge(audit_metadata)
    )
  end
end
