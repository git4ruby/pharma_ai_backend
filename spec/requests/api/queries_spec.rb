require 'rails_helper'

RSpec.describe 'Api::Queries', type: :request do
  let(:doctor) { User.create!(email: 'doctor@example.com', first_name: 'Doc', last_name: 'Smith', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
  let(:researcher) { User.create!(email: 'researcher@example.com', first_name: 'Research', last_name: 'Jones', role: :researcher, password: 'Password123!', password_confirmation: 'Password123!') }

  describe 'GET /api/queries' do
    before do
      @query1 = Query.create!(
        user: doctor,
        question: 'What is the dosage?',
        answer: 'The dosage is 500mg',
        status: 'completed',
        processing_time: 1.5,
        queried_at: 2.hours.ago
      )

      @query2 = Query.create!(
        user: researcher,
        question: 'What are side effects?',
        answer: 'Common side effects include nausea',
        status: 'completed',
        processing_time: 1.2,
        queried_at: 1.hour.ago
      )
    end

    context 'as authenticated user' do
      it 'returns only their own queries' do
        get '/api/queries', headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'][0]['id']).to eq(@query1.id)
        expect(json_response['data'][0]['question']).to eq('What is the dosage?')
      end

      it 'returns queries in recent order' do
        Query.create!(
          user: doctor,
          question: 'New question?',
          status: 'pending',
          queried_at: Time.current
        )

        get '/api/queries', headers: auth_headers_for(doctor)

        questions = json_response['data'].map { |q| q['question'] }
        expect(questions.first).to eq('New question?')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/queries'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/queries/:id' do
    let(:document) do
      Document.create!(
        user: doctor,
        title: 'Test Doc',
        filename: 'test.pdf',
        file_path: '/path/test.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'hash1',
        status: 'completed'
      )
    end

    let(:embedding) do
      Embedding.create!(
        document: document,
        chunk_text: 'The dosage is 500mg twice daily.',
        chunk_index: 0,
        embedding: [0.1, 0.2, 0.3].to_json,
        embedding_model: 'test-model'
      )
    end

    let(:query) do
      Query.create!(
        user: doctor,
        question: 'What is the dosage?',
        answer: 'The dosage is 500mg',
        status: 'completed',
        processing_time: 1.5
      )
    end

    before do
      Citation.create!(
        query: query,
        document: document,
        embedding: embedding,
        relevance_score: 0.95
      )
    end

    context 'as query owner' do
      it 'returns the query with citations' do
        get "/api/queries/#{query.id}", headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(query.id)
        expect(json_response['data']['citations']).to be_present
        expect(json_response['data']['citations'].length).to eq(1)
        expect(json_response['data']['citations'][0]['relevance_score']).to eq(0.95)
      end
    end

    context 'with non-existent id' do
      it 'returns not found' do
        get '/api/queries/99999', headers: auth_headers_for(doctor)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/queries' do
    let(:document) do
      Document.create!(
        user: doctor,
        title: 'Medical Guide',
        filename: 'guide.pdf',
        file_path: '/path/guide.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'hash1',
        status: 'completed'
      )
    end

    let(:embedding) do
      Embedding.create!(
        document: document,
        chunk_text: 'The recommended dosage is 500mg twice daily with food.',
        chunk_index: 0,
        embedding: [0.5, 0.5, 0.5].to_json,
        embedding_model: 'test-model'
      )
    end

    before do
      allow(SemanticSearch).to receive(:search).and_return([
        {
          chunk_text: 'The recommended dosage is 500mg twice daily with food.',
          similarity: 0.95,
          document: document,
          embedding: embedding
        }
      ])

      allow_any_instance_of(OllamaService).to receive(:generate_answer)
        .and_return('The recommended dosage is 500mg twice daily with food.')
    end

    context 'with valid question' do
      it 'creates a query and returns answer with citations' do
        expect {
          post '/api/queries',
               params: { question: 'What is the dosage?' },
               headers: auth_headers_for(doctor)
        }.to change(Query, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['question']).to eq('What is the dosage?')
        expect(json_response['data']['answer']).to be_present
        expect(json_response['data']['status']).to eq('completed')
        expect(json_response['data']['citations']).to be_present
      end

      it 'records processing time' do
        post '/api/queries',
             params: { question: 'What is the dosage?' },
             headers: auth_headers_for(doctor)

        expect(json_response['data']['processing_time']).to be > 0
      end
    end

    context 'without question parameter' do
      it 'returns error' do
        post '/api/queries',
             params: {},
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('question parameter is required')
      end
    end

    context 'when no documents found' do
      before do
        allow(SemanticSearch).to receive(:search).and_return([])
      end

      it 'returns not found error' do
        post '/api/queries',
             params: { question: 'What is the dosage?' },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:not_found)
        expect(json_response['errors']).to include('Please upload relevant documents first')
      end
    end

    context 'when Ollama service is unavailable' do
      before do
        allow_any_instance_of(OllamaService).to receive(:generate_answer)
          .and_raise(OllamaService::ConnectionError.new('Service unavailable'))
      end

      it 'returns service unavailable error' do
        post '/api/queries',
             params: { question: 'What is the dosage?' },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response['status']['message']).to eq('AI service unavailable')
      end

      it 'marks query as failed' do
        post '/api/queries',
             params: { question: 'What is the dosage?' },
             headers: auth_headers_for(doctor)

        query = Query.last
        expect(query.status).to eq('failed')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(SemanticSearch).to receive(:search).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns internal server error' do
        post '/api/queries',
             params: { question: 'What is the dosage?' },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:internal_server_error)
        expect(json_response['status']['message']).to eq('Query processing failed')
      end

      it 'marks query as failed' do
        post '/api/queries',
             params: { question: 'What is the dosage?' },
             headers: auth_headers_for(doctor)

        query = Query.last
        expect(query.status).to eq('failed')
      end
    end
  end
end
