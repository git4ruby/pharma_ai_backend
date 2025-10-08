require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:resource).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:action) }
    it { should validate_presence_of(:performed_at) }
  end

  describe 'scopes' do
    let(:user1) { User.create!(email: 'user1@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:user2) { User.create!(email: 'user2@example.com', first_name: 'Jane', last_name: 'Smith', role: :admin, password: 'Password123!', password_confirmation: 'Password123!') }

    before do
      @log1 = AuditLog.create!(
        user: user1,
        action: AuditLog::ACTIONS[:login],
        performed_at: 2.hours.ago,
        ip_address: '127.0.0.1'
      )

      @log2 = AuditLog.create!(
        user: user2,
        action: AuditLog::ACTIONS[:document_upload],
        performed_at: 1.hour.ago,
        ip_address: '127.0.0.2'
      )

      @log3 = AuditLog.create!(
        user: user1,
        action: AuditLog::ACTIONS[:failed_login],
        performed_at: 30.minutes.ago,
        ip_address: '127.0.0.1'
      )
    end

    describe '.recent' do
      it 'orders audit logs by performed_at descending' do
        expect(AuditLog.recent.first).to eq(@log3)
        expect(AuditLog.recent.last).to eq(@log1)
      end
    end

    describe '.by_user' do
      it 'returns audit logs for specified user' do
        logs = AuditLog.by_user(user1)
        expect(logs).to include(@log1, @log3)
        expect(logs).not_to include(@log2)
      end
    end

    describe '.by_action' do
      it 'returns audit logs with specified action' do
        logs = AuditLog.by_action(AuditLog::ACTIONS[:login])
        expect(logs).to include(@log1)
        expect(logs).not_to include(@log2, @log3)
      end
    end

    describe '.by_date_range' do
      it 'returns audit logs within date range' do
        start_date = 90.minutes.ago
        end_date = 45.minutes.ago
        logs = AuditLog.by_date_range(start_date, end_date)
        expect(logs).to include(@log2)
        expect(logs).not_to include(@log1, @log3)
      end
    end

    describe '.security_events' do
      it 'returns security-related audit logs' do
        logs = AuditLog.security_events
        expect(logs).to include(@log3)
        expect(logs).not_to include(@log1, @log2)
      end
    end

    describe '.phi_access' do
      before do
        @phi_log = AuditLog.create!(
          user: user1,
          action: AuditLog::ACTIONS[:document_view],
          performed_at: 10.minutes.ago,
          ip_address: '127.0.0.1'
        )
      end

      it 'returns PHI access audit logs' do
        logs = AuditLog.phi_access
        expect(logs).to include(@phi_log)
        expect(logs).not_to include(@log1, @log2, @log3)
      end
    end
  end

  describe '.log_action' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:document) do
      Document.create!(
        user: user,
        title: 'Test Document',
        filename: 'test.pdf',
        file_path: '/path/test.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'test_hash',
        status: 'completed'
      )
    end

    it 'creates a new audit log with provided parameters' do
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)

      log = AuditLog.log_action(
        user: user,
        action: AuditLog::ACTIONS[:document_upload],
        resource: document,
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0',
        metadata: { file_size: 1000 }
      )

      expect(log).to be_persisted
      expect(log.user).to eq(user)
      expect(log.action).to eq(AuditLog::ACTIONS[:document_upload])
      expect(log.resource).to eq(document)
      expect(log.ip_address).to eq('192.168.1.1')
      expect(log.user_agent).to eq('Mozilla/5.0')
      expect(log.metadata).to eq({ 'file_size' => 1000 })
      expect(log.performed_at).to eq(freeze_time)
    end

    it 'creates audit log without optional parameters' do
      log = AuditLog.log_action(
        user: user,
        action: AuditLog::ACTIONS[:login]
      )

      expect(log).to be_persisted
      expect(log.user).to eq(user)
      expect(log.action).to eq(AuditLog::ACTIONS[:login])
    end
  end

  describe 'immutability' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:audit_log) do
      AuditLog.create!(
        user: user,
        action: AuditLog::ACTIONS[:login],
        performed_at: Time.current,
        ip_address: '127.0.0.1'
      )
    end

    describe 'update prevention' do
      it 'raises error when attempting to update' do
        expect {
          audit_log.update(action: AuditLog::ACTIONS[:logout])
        }.to raise_error(ActiveRecord::ReadOnlyRecord, 'Audit logs cannot be modified')
      end
    end

    describe 'delete prevention' do
      it 'raises error when attempting to destroy' do
        expect {
          audit_log.destroy
        }.to raise_error(ActiveRecord::ReadOnlyRecord, 'Audit logs cannot be deleted')
      end
    end
  end

  describe 'constants' do
    it 'has all required action types' do
      expect(AuditLog::ACTIONS).to include(
        login: 'user.login',
        logout: 'user.logout',
        failed_login: 'user.failed_login',
        document_upload: 'document.upload',
        document_view: 'document.view',
        document_download: 'document.download',
        document_delete: 'document.delete',
        query_create: 'query.create',
        query_view: 'query.view',
        user_create: 'user.create',
        user_update: 'user.update',
        user_delete: 'user.delete',
        config_change: 'system.config_change',
        security_event: 'system.security_event'
      )
    end
  end
end
