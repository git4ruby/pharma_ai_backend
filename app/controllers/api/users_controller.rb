# API Users Controller
# Demonstrates RBAC - Only admins can manage users
#
# This controller shows how to use the Authorizable concern
# to protect endpoints based on user roles

module Api
  class UsersController < ApplicationController
    include Authorizable

    before_action :authenticate_user!
    before_action :authorize_admin, only: [:index, :destroy, :update_role]

    # GET /api/users
    # List all users (admin only)
    def index
      users = User.all.order(created_at: :desc)
      render json: {
        status: { code: 200, message: 'Users retrieved successfully.' },
        data: {
          users: users.map { |u| UserSerializer.new(u).serializable_hash[:data][:attributes] }
        }
      }, status: :ok
    end

    # GET /api/users/me
    # Get current user's profile (any authenticated user)
    def me
      render json: {
        status: { code: 200, message: 'User profile retrieved.' },
        data: {
          user: UserSerializer.new(current_user).serializable_hash[:data][:attributes],
          permissions: {
            can_upload_documents: current_user.can_upload_documents?,
            can_search_documents: current_user.can_search_documents?,
            can_manage_users: current_user.can_manage_users?,
            can_view_audit_logs: current_user.can_view_audit_logs?,
            can_delete_documents: current_user.can_delete_documents?,
            can_access_analytics: current_user.can_access_analytics?
          }
        }
      }, status: :ok
    end

    # PATCH /api/users/:id/role
    # Update user's role (admin only)
    def update_role
      user = User.find(params[:id])

      if user.update(role: params[:role])
        render json: {
          status: { code: 200, message: 'User role updated successfully.' },
          data: {
            user: UserSerializer.new(user).serializable_hash[:data][:attributes]
          }
        }, status: :ok
      else
        render json: {
          status: { code: 422, message: 'Role update failed.', errors: user.errors.full_messages }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/users/:id
    # Delete a user (admin only)
    def destroy
      user = User.find(params[:id])

      if user.id == current_user.id
        render json: {
          status: { code: 422, message: 'Cannot delete your own account.' }
        }, status: :unprocessable_entity
        return
      end

      user.destroy
      render json: {
        status: { code: 200, message: 'User deleted successfully.' }
      }, status: :ok
    end
  end
end
