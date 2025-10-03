module Api
  module Auth
    class RegistrationsController < Devise::RegistrationsController
      respond_to :json
      before_action :configure_sign_up_params, only: [:create]
      before_action :configure_account_update_params, only: [:update]
      before_action :authenticate_user!, only: [:update, :destroy]

      def create
        build_resource(sign_up_params)

        resource.save
        yield resource if block_given?

        if resource.persisted?
          render json: {
            status: { code: 201, message: 'User registered successfully.' },
            data: {
              user: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }
          }, status: :created
        else
          clean_up_passwords resource
          set_minimum_password_length
          render json: {
            status: { code: 422, message: 'User registration failed.', errors: resource.errors.full_messages }
          }, status: :unprocessable_entity
        end
      end

      def update
        self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)

        resource_updated = update_resource(resource, account_update_params)
        yield resource if block_given?

        if resource_updated
          render json: {
            status: { code: 200, message: 'Profile updated successfully.' },
            data: {
              user: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }
          }, status: :ok
        else
          clean_up_passwords resource
          render json: {
            status: { code: 422, message: 'Profile update failed.', errors: resource.errors.full_messages }
          }, status: :unprocessable_entity
        end
      end

      def destroy
        resource.destroy
        render json: {
          status: { code: 200, message: 'Account deleted successfully.' }
        }, status: :ok
      end

      private

      def update_resource(resource, params)
        # Allow updating without current password for profile changes
        if params[:password].blank? && params[:password_confirmation].blank?
          params.delete(:password)
          params.delete(:password_confirmation)
          resource.update_without_password(params)
        else
          resource.update_with_password(params)
        end
      end

      def respond_with(resource, _opts = {})
        if resource.persisted?
          render json: {
            status: { code: 201, message: 'User registered successfully.' },
            data: {
              user: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }
          }, status: :created
        else
          render json: {
            status: { code: 422, message: 'User registration failed.', errors: resource.errors.full_messages }
          }, status: :unprocessable_entity
        end
      end

      def configure_sign_up_params
        devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :role])
      end

      def configure_account_update_params
        devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :password, :password_confirmation, :current_password])
      end
    end
  end
end
