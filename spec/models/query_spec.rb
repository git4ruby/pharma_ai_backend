require 'rails_helper'

RSpec.describe Query, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:citations).dependent(:destroy) }
    it { should have_many(:documents).through(:citations) }
    it { should have_many(:embeddings).through(:citations) }
  end

  describe 'validations' do
    it { should validate_presence_of(:question) }
    it { should validate_length_of(:question).is_at_least(3).is_at_most(1000) }
    it { should validate_presence_of(:status) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed').backed_by_column_of_type(:string) }
  end

  describe 'scopes' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }

    before do
      @query1 = Query.create!(
        user: user,
        question: 'What is the dosage?',
        status: 'completed',
        queried_at: 2.hours.ago
      )

      @query2 = Query.create!(
        user: user,
        question: 'What are the side effects?',
        status: 'pending',
        queried_at: 1.hour.ago
      )
    end

    describe '.recent' do
      it 'orders queries by queried_at descending' do
        expect(Query.recent.first).to eq(@query2)
        expect(Query.recent.last).to eq(@query1)
      end
    end

    describe '.by_status' do
      it 'returns queries with specified status' do
        expect(Query.by_status('completed')).to include(@query1)
        expect(Query.by_status('completed')).not_to include(@query2)
      end
    end

    describe '.successful' do
      it 'returns only completed queries' do
        expect(Query.successful).to include(@query1)
        expect(Query.successful).not_to include(@query2)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:query) do
      Query.create!(
        user: user,
        question: 'What is the recommended dosage?',
        status: 'pending'
      )
    end
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
        chunk_text: 'Sample text chunk',
        chunk_index: 0,
        embedding: [0.1, 0.2, 0.3].to_json,
        embedding_model: 'test-model'
      )
    end

    describe '#mark_as_processing!' do
      it 'updates status to processing' do
        query.mark_as_processing!
        expect(query.status).to eq('processing')
      end
    end

    describe '#mark_as_completed!' do
      it 'updates status to completed and sets answer and processing_time' do
        answer = 'The recommended dosage is 500mg'
        time_taken = 1.5

        query.mark_as_completed!(answer, time_taken)

        expect(query.status).to eq('completed')
        expect(query.answer).to eq(answer)
        expect(query.processing_time).to eq(time_taken)
      end
    end

    describe '#mark_as_failed!' do
      it 'updates status to failed' do
        query.mark_as_failed!
        expect(query.status).to eq('failed')
      end
    end

    describe '#add_citation' do
      it 'creates a new citation with provided parameters' do
        expect {
          query.add_citation(
            document: document,
            embedding: embedding,
            score: 0.85
          )
        }.to change { query.citations.count }.by(1)

        citation = query.citations.last
        expect(citation.document).to eq(document)
        expect(citation.embedding).to eq(embedding)
        expect(citation.relevance_score).to eq(0.85)
      end
    end

    describe '#top_citations' do
      before do
        query.add_citation(document: document, embedding: embedding, score: 0.9)
        query.add_citation(document: document, embedding: embedding, score: 0.7)
        query.add_citation(document: document, embedding: embedding, score: 0.85)
      end

      it 'returns citations ordered by relevance score descending' do
        top = query.top_citations(2)
        expect(top.count).to eq(2)
        expect(top.first.relevance_score).to eq(0.9)
        expect(top.last.relevance_score).to eq(0.85)
      end

      it 'limits results to specified count' do
        expect(query.top_citations(2).count).to eq(2)
      end

      it 'defaults to 5 results' do
        expect(query.top_citations.count).to eq(3)
      end
    end
  end
end
