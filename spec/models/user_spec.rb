require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:audit_logs).dependent(:restrict_with_error) }
    it { should have_many(:documents).dependent(:destroy) }
    it { should have_many(:queries).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:role) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(doctor: 0, researcher: 1, auditor: 2, admin: 3) }
  end

  describe '#full_name' do
    it 'returns the concatenated first and last name' do
      user = User.new(first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe 'password complexity validation' do
    context 'with valid password' do
      it 'accepts password with all required elements' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'Password123!',
          password_confirmation: 'Password123!'
        )
        expect(user).to be_valid
      end
    end

    context 'with invalid password' do
      it 'rejects password without uppercase letter' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'password123!@#',
          password_confirmation: 'password123!@#'
        )
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('must be at least 12 characters and include uppercase, lowercase, number, and special character')
      end

      it 'rejects password without lowercase letter' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'PASSWORD123!@#',
          password_confirmation: 'PASSWORD123!@#'
        )
        expect(user).not_to be_valid
      end

      it 'rejects password without number' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'Password!@#$%',
          password_confirmation: 'Password!@#$%'
        )
        expect(user).not_to be_valid
      end

      it 'rejects password without special character' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'Password12345',
          password_confirmation: 'Password12345'
        )
        expect(user).not_to be_valid
      end

      it 'rejects password shorter than 12 characters' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'Pass123!',
          password_confirmation: 'Pass123!'
        )
        expect(user).not_to be_valid
      end
    end
  end

  describe 'permission methods' do
    describe '#can_upload_documents?' do
      it 'returns true for doctor role' do
        user = User.new(role: :doctor)
        expect(user.can_upload_documents?).to be true
      end

      it 'returns true for admin role' do
        user = User.new(role: :admin)
        expect(user.can_upload_documents?).to be true
      end

      it 'returns false for researcher role' do
        user = User.new(role: :researcher)
        expect(user.can_upload_documents?).to be false
      end

      it 'returns false for auditor role' do
        user = User.new(role: :auditor)
        expect(user.can_upload_documents?).to be false
      end
    end

    describe '#can_search_documents?' do
      it 'returns true for all roles' do
        [:doctor, :researcher, :auditor, :admin].each do |role|
          user = User.new(role: role)
          expect(user.can_search_documents?).to be true
        end
      end
    end

    describe '#can_manage_users?' do
      it 'returns true for admin role' do
        user = User.new(role: :admin)
        expect(user.can_manage_users?).to be true
      end

      it 'returns false for non-admin roles' do
        [:doctor, :researcher, :auditor].each do |role|
          user = User.new(role: role)
          expect(user.can_manage_users?).to be false
        end
      end
    end

    describe '#can_view_audit_logs?' do
      it 'returns true for auditor role' do
        user = User.new(role: :auditor)
        expect(user.can_view_audit_logs?).to be true
      end

      it 'returns true for admin role' do
        user = User.new(role: :admin)
        expect(user.can_view_audit_logs?).to be true
      end

      it 'returns false for other roles' do
        [:doctor, :researcher].each do |role|
          user = User.new(role: role)
          expect(user.can_view_audit_logs?).to be false
        end
      end
    end

    describe '#can_delete_documents?' do
      it 'returns true for admin role' do
        user = User.new(role: :admin)
        expect(user.can_delete_documents?).to be true
      end

      it 'returns false for non-admin roles' do
        [:doctor, :researcher, :auditor].each do |role|
          user = User.new(role: role)
          expect(user.can_delete_documents?).to be false
        end
      end
    end

    describe '#can_access_analytics?' do
      it 'returns true for researcher role' do
        user = User.new(role: :researcher)
        expect(user.can_access_analytics?).to be true
      end

      it 'returns true for doctor role' do
        user = User.new(role: :doctor)
        expect(user.can_access_analytics?).to be true
      end

      it 'returns true for admin role' do
        user = User.new(role: :admin)
        expect(user.can_access_analytics?).to be true
      end

      it 'returns false for auditor role' do
        user = User.new(role: :auditor)
        expect(user.can_access_analytics?).to be false
      end
    end
  end

  describe '#can_access?' do
    let(:user) { User.new(id: 1, role: :doctor) }
    let(:admin) { User.new(id: 2, role: :admin) }
    let(:resource) { double('Resource', user_id: 1) }
    let(:other_resource) { double('Resource', user_id: 3) }

    it 'returns true for admin regardless of resource ownership' do
      expect(admin.can_access?(other_resource)).to be true
    end

    it 'returns true when user owns the resource' do
      expect(user.can_access?(resource)).to be true
    end

    it 'returns false when user does not own the resource' do
      expect(user.can_access?(other_resource)).to be false
    end

    it 'returns false when resource does not respond to user_id' do
      no_user_resource = double('Resource')
      expect(user.can_access?(no_user_resource)).to be false
    end
  end

  describe 'callbacks' do
    describe '#generate_jti' do
      it 'generates a JWT ID before creation' do
        user = User.new(
          email: 'test@example.com',
          first_name: 'John',
          last_name: 'Doe',
          role: :doctor,
          password: 'Password123!',
          password_confirmation: 'Password123!'
        )

        expect(user.jti).to be_nil
        user.save!
        user.reload
        expect(user.jti).to be_present
        expect(user.jti).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end
  end
end
