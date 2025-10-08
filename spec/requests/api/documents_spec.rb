require 'rails_helper'

RSpec.describe 'Api::Documents', type: :request do
  let(:doctor) { User.create!(email: 'doctor@example.com', first_name: 'Doc', last_name: 'Smith', role: :doctor, password: 'Password123!', password_confirmation: 'Password123!') }
  let(:researcher) { User.create!(email: 'researcher@example.com', first_name: 'Research', last_name: 'Jones', role: :researcher, password: 'Password123!', password_confirmation: 'Password123!') }
  let(:admin) { User.create!(email: 'admin@example.com', first_name: 'Admin', last_name: 'User', role: :admin, password: 'Password123!', password_confirmation: 'Password123!') }

  describe 'GET /api/documents' do
    before do
      @doc1 = Document.create!(
        user: doctor,
        title: 'Doctor Document',
        filename: 'doc1.pdf',
        file_path: '/path/doc1.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'hash1',
        status: 'completed'
      )

      @doc2 = Document.create!(
        user: researcher,
        title: 'Researcher Document',
        filename: 'doc2.pdf',
        file_path: '/path/doc2.pdf',
        file_type: 'application/pdf',
        file_size: 2000,
        content_hash: 'hash2',
        status: 'completed'
      )
    end

    context 'as doctor' do
      it 'returns only their own documents' do
        get '/api/documents', headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'][0]['id']).to eq(@doc1.id)
      end
    end

    context 'as admin' do
      it 'returns all documents' do
        get '/api/documents', headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(2)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/documents'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/documents/:id' do
    let(:document) do
      Document.create!(
        user: doctor,
        title: 'Test Document',
        filename: 'test.pdf',
        file_path: '/path/test.pdf',
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'test_hash',
        status: 'completed'
      )
    end

    context 'as document owner' do
      it 'returns the document' do
        get "/api/documents/#{document.id}", headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(document.id)
        expect(json_response['data']['title']).to eq('Test Document')
      end
    end

    context 'as different user' do
      it 'returns forbidden' do
        get "/api/documents/#{document.id}", headers: auth_headers_for(researcher)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as admin' do
      it 'can access any document' do
        get "/api/documents/#{document.id}", headers: auth_headers_for(admin)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(document.id)
      end
    end

    context 'with non-existent id' do
      it 'returns not found' do
        get '/api/documents/99999', headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/documents' do
    let(:pdf_content) { '%PDF-1.4 fake pdf content' }
    let(:file) { Rack::Test::UploadedFile.new(StringIO.new(pdf_content), 'application/pdf', original_filename: 'test.pdf') }

    context 'as doctor' do
      it 'uploads document successfully' do
        expect {
          post '/api/documents',
               params: { file: file, title: 'New Document' },
               headers: auth_headers_for(doctor)
        }.to change(Document, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['title']).to eq('New Document')
        expect(json_response['data']['filename']).to eq('test.pdf')
        expect(json_response['data']['status']).to eq('pending')
      end

      it 'uses filename as title if title not provided' do
        post '/api/documents',
             params: { file: file },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:created)
        expect(json_response['data']['title']).to eq('test')
      end

      it 'detects duplicate documents' do
        post '/api/documents',
             params: { file: file, title: 'First Upload' },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:created)
        first_doc_id = json_response['data']['id']

        file2 = Rack::Test::UploadedFile.new(StringIO.new(pdf_content), 'application/pdf', original_filename: 'duplicate.pdf')
        post '/api/documents',
             params: { file: file2, title: 'Duplicate Upload' },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:conflict)
        expect(json_response['data']['id']).to eq(first_doc_id)
      end
    end

    context 'as researcher' do
      it 'returns forbidden' do
        post '/api/documents',
             params: { file: file, title: 'Should Fail' },
             headers: auth_headers_for(researcher)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid file type' do
      let(:exe_file) { Rack::Test::UploadedFile.new(StringIO.new('fake exe'), 'application/x-msdownload', original_filename: 'virus.exe') }

      it 'returns error' do
        post '/api/documents',
             params: { file: exe_file },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include(match(/not allowed/))
      end
    end

    context 'without file parameter' do
      it 'returns error' do
        post '/api/documents',
             params: { title: 'No File' },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('file parameter is required')
      end
    end

    context 'with file too large' do
      let(:large_content) { 'x' * (Document::MAX_FILE_SIZE + 1) }
      let(:large_file) { Rack::Test::UploadedFile.new(StringIO.new(large_content), 'application/pdf', original_filename: 'huge.pdf') }

      it 'returns error' do
        post '/api/documents',
             params: { file: large_file },
             headers: auth_headers_for(doctor)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include(match(/exceeds maximum/))
      end
    end
  end

  describe 'DELETE /api/documents/:id' do
    let(:test_file_path) { Rails.root.join('tmp', 'test_documents', 'delete_test.pdf') }
    let(:document) do
      Document.create!(
        user: doctor,
        title: 'To Delete',
        filename: 'delete.pdf',
        file_path: test_file_path.to_s,
        file_type: 'application/pdf',
        file_size: 1000,
        content_hash: 'delete_hash',
        status: 'completed'
      )
    end

    context 'as different user' do
      it 'returns forbidden' do
        delete "/api/documents/#{document.id}", headers: auth_headers_for(researcher)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as document owner or admin' do
      before do
        FileUtils.mkdir_p(File.dirname(test_file_path))
        File.write(test_file_path, 'test content')
      end

      after do
        File.delete(test_file_path) if File.exist?(test_file_path)
        FileUtils.rm_rf(Rails.root.join('tmp', 'test_documents'))
      end

      it 'allows owner to delete their own document' do
        delete "/api/documents/#{document.id}", headers: auth_headers_for(doctor)
        expect(response).to have_http_status(:ok)
      end

      it 'allows admin to delete any document' do
        delete "/api/documents/#{document.id}", headers: auth_headers_for(admin)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
