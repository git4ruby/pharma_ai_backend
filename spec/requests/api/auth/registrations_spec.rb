require 'rails_helper'

RSpec.describe 'Api::Auth::Registrations', type: :request do
  describe 'POST /api/auth/signup' do
    let(:valid_params) do
      {
        user: {
          email: 'newuser@example.com',
          password: 'Password123!',
          password_confirmation: 'Password123!',
          first_name: 'John',
          last_name: 'Doe',
          role: 'doctor'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new user and returns JWT token' do
        expect {
          post '/api/auth/signup', params: valid_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['status']['code']).to eq(201)
        expect(json_response['data']['user']['email']).to eq('newuser@example.com')
        expect(json_response['data']['token']).to be_present
      end

      it 'returns user data with correct attributes' do
        post '/api/auth/signup', params: valid_params

        user_data = json_response['data']['user']
        expect(user_data['first_name']).to eq('John')
        expect(user_data['last_name']).to eq('Doe')
        expect(user_data['role']).to eq('doctor')
        expect(user_data['full_name']).to eq('John Doe')
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing email' do
        invalid_params = valid_params.dup
        invalid_params[:user].delete(:email)

        post '/api/auth/signup', params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['code']).to eq(422)
        expect(json_response['status']['errors']).to be_present
      end

      it 'returns error for weak password' do
        invalid_params = valid_params.dup
        invalid_params[:user][:password] = 'weak'
        invalid_params[:user][:password_confirmation] = 'weak'

        post '/api/auth/signup', params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['errors']).to include(match(/must be at least 12 characters/))
      end

      it 'returns error for mismatched password confirmation' do
        invalid_params = valid_params.dup
        invalid_params[:user][:password_confirmation] = 'DifferentPassword123!'

        post '/api/auth/signup', params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['errors']).to include(match(/Password confirmation doesn't match/))
      end

      it 'returns error for duplicate email' do
        User.create!(
          email: 'existing@example.com',
          password: 'Password123!',
          first_name: 'Existing',
          last_name: 'User',
          role: :doctor
        )

        duplicate_params = valid_params.dup
        duplicate_params[:user][:email] = 'existing@example.com'

        post '/api/auth/signup', params: duplicate_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']['errors']).to include(match(/Email has already been taken/))
      end
    end
  end
end
