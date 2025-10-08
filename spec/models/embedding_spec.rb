require 'rails_helper'

RSpec.describe Embedding, type: :model do
  describe 'associations' do
    it { should belong_to(:document) }
  end

  describe 'validations' do
    it { should validate_presence_of(:chunk_text) }
    it { should validate_presence_of(:chunk_index) }
    it { should validate_presence_of(:embedding) }
    it { should validate_presence_of(:embedding_model) }
    it { should validate_numericality_of(:chunk_index).only_integer }
    it { should validate_numericality_of(:chunk_index).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let(:user) { User.create!(email: 'test@example.com', first_name: 'John', last_name: 'Doe', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
    let(:document1) do
      Document.create!(
        user: user,
        title: 'Document 1',
        filename: 'doc1.pdf',
        file_path: '/path/doc1.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'hash1',
        status: 'completed'
      )
    end
    let(:document2) do
      Document.create!(
        user: user,
        title: 'Document 2',
        filename: 'doc2.pdf',
        file_path: '/path/doc2.pdf',
        file_type: 'application/pdf',
        file_size: 2000,
        content_hash: 'hash2',
        status: 'completed'
      )
    end

    before do
      @emb1 = Embedding.create!(
        document: document1,
        chunk_text: 'First chunk',
        chunk_index: 0,
        embedding: [0.1, 0.2].to_json,
        embedding_model: 'test-model'
      )
      @emb2 = Embedding.create!(
        document: document1,
        chunk_text: 'Second chunk',
        chunk_index: 1,
        embedding: [0.3, 0.4].to_json,
        embedding_model: 'test-model'
      )
      @emb3 = Embedding.create!(
        document: document2,
        chunk_text: 'Third chunk',
        chunk_index: 0,
        embedding: [0.5, 0.6].to_json,
        embedding_model: 'test-model'
      )
    end

    describe '.by_document' do
      it 'returns embeddings for specified document' do
        embeddings = Embedding.by_document(document1)
        expect(embeddings).to include(@emb1, @emb2)
        expect(embeddings).not_to include(@emb3)
      end
    end

    describe '.ordered' do
      it 'orders embeddings by chunk_index ascending' do
        embeddings = Embedding.by_document(document1).ordered
        expect(embeddings.first).to eq(@emb1)
        expect(embeddings.last).to eq(@emb2)
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

    describe '#embedding_vector' do
      it 'returns parsed JSON array' do
        expect(embedding.embedding_vector).to eq([0.1, 0.2, 0.3])
      end

      it 'caches the parsed vector' do
        first_call = embedding.embedding_vector
        second_call = embedding.embedding_vector
        expect(first_call.object_id).to eq(second_call.object_id)
      end

      it 'returns empty array on JSON parse error' do
        embedding.update_column(:embedding, 'invalid json')
        expect(embedding.embedding_vector).to eq([])
      end
    end

    describe '#embedding_vector=' do
      it 'sets embedding as JSON string and caches vector' do
        embedding.embedding_vector = [0.5, 0.6, 0.7]
        expect(embedding.embedding).to eq([0.5, 0.6, 0.7].to_json)
        expect(embedding.embedding_vector).to eq([0.5, 0.6, 0.7])
      end
    end
  end

  describe '.cosine_similarity' do
    it 'calculates correct similarity for identical vectors' do
      vec1 = [1.0, 0.0, 0.0]
      vec2 = [1.0, 0.0, 0.0]
      expect(Embedding.cosine_similarity(vec1, vec2)).to eq(1.0)
    end

    it 'calculates correct similarity for orthogonal vectors' do
      vec1 = [1.0, 0.0, 0.0]
      vec2 = [0.0, 1.0, 0.0]
      expect(Embedding.cosine_similarity(vec1, vec2)).to eq(0.0)
    end

    it 'calculates correct similarity for opposite vectors' do
      vec1 = [1.0, 0.0, 0.0]
      vec2 = [-1.0, 0.0, 0.0]
      expect(Embedding.cosine_similarity(vec1, vec2)).to eq(-1.0)
    end

    it 'calculates correct similarity for arbitrary vectors' do
      vec1 = [1.0, 2.0, 3.0]
      vec2 = [4.0, 5.0, 6.0]

      dot_product = 1.0*4.0 + 2.0*5.0 + 3.0*6.0
      mag1 = Math.sqrt(1.0**2 + 2.0**2 + 3.0**2)
      mag2 = Math.sqrt(4.0**2 + 5.0**2 + 6.0**2)
      expected = dot_product / (mag1 * mag2)

      expect(Embedding.cosine_similarity(vec1, vec2)).to be_within(0.0001).of(expected)
    end

    it 'returns 0 for nil vectors' do
      expect(Embedding.cosine_similarity(nil, [1, 2])).to eq(0)
      expect(Embedding.cosine_similarity([1, 2], nil)).to eq(0)
    end

    it 'returns 0 for empty vectors' do
      expect(Embedding.cosine_similarity([], [1, 2])).to eq(0)
      expect(Embedding.cosine_similarity([1, 2], [])).to eq(0)
    end

    it 'returns 0 for vectors with different lengths' do
      expect(Embedding.cosine_similarity([1, 2], [1, 2, 3])).to eq(0)
    end

    it 'returns 0 when magnitude is zero' do
      expect(Embedding.cosine_similarity([0, 0], [1, 2])).to eq(0)
    end
  end

  describe '.find_similar' do
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

    before do
      @emb1 = Embedding.create!(
        document: document,
        chunk_text: 'First chunk',
        chunk_index: 0,
        embedding: [1.0, 0.0, 0.0].to_json,
        embedding_model: 'test-model'
      )
      @emb2 = Embedding.create!(
        document: document,
        chunk_text: 'Second chunk',
        chunk_index: 1,
        embedding: [0.0, 1.0, 0.0].to_json,
        embedding_model: 'test-model'
      )
      @emb3 = Embedding.create!(
        document: document,
        chunk_text: 'Third chunk',
        chunk_index: 2,
        embedding: [0.9, 0.1, 0.0].to_json,
        embedding_model: 'test-model'
      )
    end

    it 'finds most similar embeddings to query vector' do
      query_vec = [1.0, 0.0, 0.0]
      results = Embedding.find_similar(query_vec, limit: 2)

      expect(results.length).to eq(2)
      expect(results.first[:embedding]).to eq(@emb1)
      expect(results.first[:similarity]).to eq(1.0)
    end

    it 'accepts query embedding as JSON string' do
      query_vec = [1.0, 0.0, 0.0].to_json
      results = Embedding.find_similar(query_vec, limit: 1)

      expect(results.length).to eq(1)
      expect(results.first[:embedding]).to eq(@emb1)
    end

    it 'limits results to specified count' do
      query_vec = [1.0, 0.0, 0.0]
      results = Embedding.find_similar(query_vec, limit: 2)

      expect(results.length).to eq(2)
    end

    it 'defaults to 10 results' do
      query_vec = [1.0, 0.0, 0.0]
      results = Embedding.find_similar(query_vec)

      expect(results.length).to eq(3)
    end

    it 'sorts results by similarity descending' do
      query_vec = [1.0, 0.0, 0.0]
      results = Embedding.find_similar(query_vec, limit: 3)

      expect(results[0][:similarity]).to be >= results[1][:similarity]
      expect(results[1][:similarity]).to be >= results[2][:similarity]
    end
  end
end
