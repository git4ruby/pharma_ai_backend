class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :lockable, :timeoutable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # Associations
  has_many :audit_logs, dependent: :restrict_with_error
  has_many :documents, dependent: :destroy
  has_many :queries, dependent: :destroy

  # Role enum for RBAC
  enum role: { doctor: 0, researcher: 1, auditor: 2, admin: 3 }

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true

  # Password complexity requirements for HIPAA compliance
  validate :password_complexity

  # Callbacks
  before_create :generate_jti

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  # Permission methods for RBAC
  # These define what each role can do in the system

  def can_upload_documents?
    doctor? || researcher? || admin?
  end

  def can_search_documents?
    true # All authenticated users can search
  end

  def can_manage_users?
    admin?
  end

  def can_view_audit_logs?
    auditor? || admin?
  end

  def can_delete_documents?
    admin?
  end

  def can_access_analytics?
    researcher? || doctor? || admin?
  end

  # Check if user can access a specific resource
  def can_access?(resource)
    return true if admin? # Admins can access everything
    return false unless resource.respond_to?(:user_id)

    resource.user_id == id # Users can only access their own resources
  end

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{12,}$/)
      errors.add :password, 'must be at least 12 characters and include uppercase, lowercase, number, and special character'
    end
  end

  def generate_jti
    self.jti ||= SecureRandom.uuid
  end
end
