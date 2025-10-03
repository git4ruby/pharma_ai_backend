class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :lockable, :timeoutable,
         :jwt_authenticatable, jwt_revocation_strategy: self

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
