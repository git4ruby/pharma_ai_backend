require 'rails_helper'

RSpec.describe Citation, type: :model do
  describe 'associations' do
    it { should belong_to(:query) }
    it { should belong_to(:document) }
    it { should belong_to(:embedding) }
  end

  describe 'validations' do
    it { should validate_presence_of(:relevance_score) }
    it { should validate_numericality_of(:relevance_score).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:relevance_score).is_less_than_or_equal_to(1) }
  end

  describe 'scopes' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:query) { Query.create!(user: user, question: 'Test question?', status: 'pending') }
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
    let(:embedding) do
      Embedding.create!(
        document: document,
        chunk_text: 'Sample text',
        chunk_index: 0,
        embedding: [0.1, 0.2].to_json,
        embedding_model: 'test-model'
      )
    end

    before do
      @citation1 = Citation.create!(query: query, document: document, embedding: embedding, relevance_score: 0.9)
      @citation2 = Citation.create!(query: query, document: document, embedding: embedding, relevance_score: 0.6)
      @citation3 = Citation.create!(query: query, document: document, embedding: embedding, relevance_score: 0.75)
    end

    describe '.ordered_by_relevance' do
      it 'orders citations by relevance score descending' do
        citations = Citation.ordered_by_relevance
        expect(citations.first).to eq(@citation1)
        expect(citations.last).to eq(@citation2)
      end
    end

    describe '.high_relevance' do
      it 'returns only citations with relevance score >= 0.7' do
        citations = Citation.high_relevance
        expect(citations).to include(@citation1, @citation3)
        expect(citations).not_to include(@citation2)
      end
    end
  end
end
