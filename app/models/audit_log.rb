class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :resource, polymorphic: true, optional: true

  # Action types for HIPAA compliance tracking
  ACTIONS = {
    # Authentication
    login: 'user.login',
    logout: 'user.logout',
    failed_login: 'user.failed_login',

    # Document actions
    document_upload: 'document.upload',
    document_view: 'document.view',
    document_download: 'document.download',
    document_delete: 'document.delete',

    # Query actions
    query_create: 'query.create',
    query_view: 'query.view',

    # User management
    user_create: 'user.create',
    user_update: 'user.update',
    user_delete: 'user.delete',

    # System events
    config_change: 'system.config_change',
    security_event: 'system.security_event'
  }.freeze

  # Validations
  validates :action, presence: true
  validates :performed_at, presence: true

  # Scopes for common queries
  scope :recent, -> { order(performed_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_date_range, ->(start_date, end_date) { where(performed_at: start_date..end_date) }
  scope :security_events, -> { where(action: [ACTIONS[:failed_login], ACTIONS[:security_event]]) }
  scope :phi_access, -> { where(action: [ACTIONS[:document_view], ACTIONS[:document_download]]) }

  # Class method to log an action
  def self.log_action(user:, action:, resource: nil, ip_address: nil, user_agent: nil, metadata: {})
    create!(
      user: user,
      action: action,
      resource: resource,
      ip_address: ip_address,
      user_agent: user_agent,
      metadata: metadata,
      performed_at: Time.current
    )
  end

  # Make audit logs immutable (cannot be updated or deleted)
  before_update :prevent_update
  before_destroy :prevent_destroy

  private

  def prevent_update
    raise ActiveRecord::ReadOnlyRecord, "Audit logs cannot be modified"
  end

  def prevent_destroy
    raise ActiveRecord::ReadOnlyRecord, "Audit logs cannot be deleted"
  end
end
