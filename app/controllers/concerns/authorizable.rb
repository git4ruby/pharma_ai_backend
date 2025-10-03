# Authorizable Concern
# This module provides role-based access control methods to controllers
#
# Usage:
#   include Authorizable
#   before_action :authorize_admin, only: [:destroy]
#   before_action -> { authorize_role(:doctor, :admin) }, only: [:create]

module Authorizable
  extend ActiveSupport::Concern

  included do
    rescue_from NotAuthorizedError, with: :user_not_authorized
  end

  # Custom error class for authorization failures
  class NotAuthorizedError < StandardError; end

  # Check if current user has a specific role
  # Example: authorize_admin
  def authorize_admin
    authorize_role(:admin)
  end

  def authorize_doctor
    authorize_role(:doctor, :admin)
  end

  def authorize_researcher
    authorize_role(:researcher, :doctor, :admin)
  end

  def authorize_auditor
    authorize_role(:auditor, :admin)
  end

  # Generic method to check if user has any of the allowed roles
  # authorize_role(:doctor, :admin) means user must be doctor OR admin
  def authorize_role(*allowed_roles)
    unless current_user && allowed_roles.map(&:to_s).include?(current_user.role)
      raise NotAuthorizedError, "You are not authorized to perform this action"
    end
  end

  # Check if current user can access a specific resource
  # Example: authorize_resource(@document) checks if user owns the document
  def authorize_resource(resource)
    unless can_access_resource?(resource)
      raise NotAuthorizedError, "You are not authorized to access this resource"
    end
  end

  # Check if user can access a resource
  # Admins can access everything
  # Others can only access their own resources
  def can_access_resource?(resource)
    return true if current_user&.admin?
    return false unless current_user

    # Check if resource belongs to current user
    resource.respond_to?(:user_id) && resource.user_id == current_user.id
  end

  private

  # Handle authorization errors by returning 403 Forbidden
  def user_not_authorized(exception)
    render json: {
      status: { code: 403, message: 'Access forbidden.' },
      error: exception.message
    }, status: :forbidden
  end
end
