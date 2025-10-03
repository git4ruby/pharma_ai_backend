module Api
  module Auth
    class PasswordsController < Devise::PasswordsController
      respond_to :json

      # POST /api/auth/password
      def create
        self.resource = resource_class.send_reset_password_instructions(resource_params)
        yield resource if block_given?

        if successfully_sent?(resource)
          render json: {
            status: { code: 200, message: 'Password reset instructions sent to your email.' }
          }, status: :ok
        else
          render json: {
            status: { code: 422, message: 'Password reset failed.', errors: resource.errors.full_messages }
          }, status: :unprocessable_entity
        end
      end

      # PUT /api/auth/password
      def update
        self.resource = resource_class.reset_password_by_token(resource_params)
        yield resource if block_given?

        if resource.errors.empty?
          resource.unlock_access! if unlockable?(resource)
          render json: {
            status: { code: 200, message: 'Password changed successfully.' }
          }, status: :ok
        else
          render json: {
            status: { code: 422, message: 'Password change failed.', errors: resource.errors.full_messages }
          }, status: :unprocessable_entity
        end
      end

      private

      def respond_with(resource, _opts = {})
        # Not used, but required by Devise
      end

      def respond_to_on_destroy
        # Not used, but required by Devise
      end
    end
  end
end
