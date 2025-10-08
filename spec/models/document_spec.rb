require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:embeddings).dependent(:destroy) }
    it { should have_many(:citations).dependent(:destroy) }
    it { should have_many(:queries).through(:citations) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:file_path) }
    it { should validate_presence_of(:file_type) }
    it { should validate_presence_of(:file_size) }
    it { should validate_presence_of(:content_hash) }
    it { should validate_presence_of(:status) }

    it { should validate_inclusion_of(:file_type).in_array(Document::ALLOWED_FILE_TYPES) }
    it { should validate_numericality_of(:file_size).is_greater_than(0) }
    it { should validate_numericality_of(:file_size).is_less_than_or_equal_to(Document::MAX_FILE_SIZE) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed').backed_by_column_of_type(:string) }
  end

  describe 'scopes' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }

    before do
      @doc_with_phi = Document.create!(
        user: user,
        title: 'PHI Document',
        filename: 'phi.pdf',
        file_path: '/path/phi.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'hash1',
        status: 'completed',
        contains_phi: true
      )

      @doc_without_phi = Document.create!(
        user: user,
        title: 'Non-PHI Document',
        filename: 'non_phi.pdf',
        file_path: '/path/non_phi.pdf',
        file_type: 'application/pdf',
        file_size: 2000,
        content_hash: 'hash2',
        status: 'pending',
        contains_phi: false
      )
    end

    describe '.with_phi' do
      it 'returns only documents with PHI' do
        expect(Document.with_phi).to include(@doc_with_phi)
        expect(Document.with_phi).not_to include(@doc_without_phi)
      end
    end

    describe '.without_phi' do
      it 'returns only documents without PHI' do
        expect(Document.without_phi).to include(@doc_without_phi)
        expect(Document.without_phi).not_to include(@doc_with_phi)
      end
    end

    describe '.by_status' do
      it 'returns documents with specified status' do
        expect(Document.by_status('completed')).to include(@doc_with_phi)
        expect(Document.by_status('completed')).not_to include(@doc_without_phi)
      end
    end

    describe '.processed' do
      it 'returns only completed documents' do
        expect(Document.processed).to include(@doc_with_phi)
        expect(Document.processed).not_to include(@doc_without_phi)
      end
    end

    describe '.recent' do
      it 'orders documents by created_at descending' do
        expect(Document.recent.first).to eq(@doc_without_phi)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:document) do
      Document.create!(
        user: user,
        title: 'Test Document',
        filename: 'test.pdf',
        file_path: '/path/test.pdf',
        file_type: 'application/pdf',
        file_size: 1048576,
        content_hash: 'test_hash',
        status: 'pending'
      )
    end

    describe '#file_extension' do
      it 'returns the file extension without dot' do
        expect(document.file_extension).to eq('pdf')
      end
    end

    describe '#human_file_size' do
      it 'returns human-readable file size' do
        expect(document.human_file_size).to eq('1 MB')
      end
    end

    describe '#mark_as_processing!' do
      it 'updates status to processing' do
        document.mark_as_processing!
        expect(document.status).to eq('processing')
      end
    end

    describe '#mark_as_completed!' do
      it 'updates status to completed and sets processed_at' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)

        document.mark_as_completed!

        expect(document.status).to eq('completed')
        expect(document.processed_at).to eq(freeze_time)
      end
    end

    describe '#mark_as_failed!' do
      it 'updates status to failed' do
        document.mark_as_failed!
        expect(document.status).to eq('failed')
      end
    end
  end

  describe 'constants' do
    it 'has correct allowed file types' do
      expect(Document::ALLOWED_FILE_TYPES).to eq([
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain'
      ])
    end

    it 'has correct max file size' do
      expect(Document::MAX_FILE_SIZE).to eq(50.megabytes)
    end
  end
end
