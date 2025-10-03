module Api
  module Auth
    class RegistrationsController < Devise::RegistrationsController
      respond_to :json

      private

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
    end
  end
end
