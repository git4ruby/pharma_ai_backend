class Api::DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_upload, only: [:create]
  before_action :set_document, only: [:show, :destroy]
  before_action :authorize_access, only: [:show, :destroy]

  def index
    @documents = current_user.admin? ? Document.all : current_user.documents
    @documents = @documents.recent.includes(:user)

    render json: {
      status: { code: 200, message: 'Documents retrieved successfully' },
      data: @documents.map { |doc| document_json(doc) }
    }
  end

  def show
    render json: {
      status: { code: 200, message: 'Document retrieved successfully' },
      data: document_json(@document)
    }
  end

  def create
    uploaded_file = params[:file]

    unless uploaded_file.present?
      return render json: {
        status: { code: 422, message: 'No file provided' },
        errors: ['file parameter is required']
      }, status: :unprocessable_entity
    end

    # Validate file type
    content_type = uploaded_file.content_type
    unless Document::ALLOWED_FILE_TYPES.include?(content_type)
      return render json: {
        status: { code: 422, message: 'Invalid file type' },
        errors: ["File type #{content_type} is not allowed. Allowed types: PDF, DOCX, TXT"]
      }, status: :unprocessable_entity
    end

    # Validate file size
    if uploaded_file.size > Document::MAX_FILE_SIZE
      return render json: {
        status: { code: 422, message: 'File too large' },
        errors: ["File size exceeds maximum of #{ActiveSupport::NumberHelper.number_to_human_size(Document::MAX_FILE_SIZE)}"]
      }, status: :unprocessable_entity
    end

    # Calculate content hash
    file_content = uploaded_file.read
    content_hash = Digest::SHA256.hexdigest(file_content)
    uploaded_file.rewind

    # Check for duplicate
    existing_document = Document.find_by(content_hash: content_hash)
    if existing_document
      return render json: {
        status: { code: 409, message: 'Document already exists' },
        data: document_json(existing_document)
      }, status: :conflict
    end

    # Create document record with Active Storage
    file_extension = File.extname(uploaded_file.original_filename)
    @document = Document.new(
      user: current_user,
      title: params[:title] || uploaded_file.original_filename.gsub(file_extension, ''),
      filename: uploaded_file.original_filename,
      file_path: "active_storage",  # Legacy field, not used with Active Storage
      file_type: content_type,
      file_size: uploaded_file.size,
      content_hash: content_hash,
      contains_phi: params[:contains_phi] == 'true' || params[:contains_phi] == true,
      classification: params[:classification] || 'unclassified',
      status: 'pending'
    )

    # Attach file using Active Storage (will upload to S3)
    @document.file.attach(
      io: StringIO.new(file_content),
      filename: uploaded_file.original_filename,
      content_type: content_type
    )

    if @document.save
      # Enqueue background job to process document
      DocumentProcessorJob.perform_later(@document.id)

      render json: {
        status: { code: 201, message: 'Document uploaded successfully to S3. Processing will begin shortly.' },
        data: document_json(@document)
      }, status: :created
    else
      render json: {
        status: { code: 422, message: 'Failed to create document' },
        errors: @document.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    render json: {
      status: { code: 500, message: 'Internal server error' },
      errors: [e.message]
    }, status: :internal_server_error
  end

  def destroy
    if @document.destroy
      # Active Storage automatically deletes the file from S3
      # Legacy local files cleanup
      if @document.file_path && @document.file_path != "active_storage" && File.exist?(@document.file_path)
        File.delete(@document.file_path)
      end

      render json: {
        status: { code: 200, message: 'Document deleted successfully' }
      }
    else
      render json: {
        status: { code: 422, message: 'Failed to delete document' },
        errors: @document.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_document
    @document = Document.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: { code: 404, message: 'Document not found' }
    }, status: :not_found
  end

  def authorize_upload
    unless current_user.can_upload_documents?
      render json: {
        status: { code: 403, message: 'You are not authorized to upload documents' }
      }, status: :forbidden
    end
  end

  def authorize_access
    unless current_user.can_access?(@document) || current_user.can_view_audit_logs?
      render json: {
        status: { code: 403, message: 'You are not authorized to access this document' }
      }, status: :forbidden
    end
  end

  def document_json(document)
    {
      id: document.id,
      title: document.title,
      filename: document.filename,
      file_type: document.file_type,
      file_size: document.file_size,
      human_file_size: document.human_file_size,
      contains_phi: document.contains_phi,
      classification: document.classification,
      status: document.status,
      processed_at: document.processed_at,
      created_at: document.created_at,
      updated_at: document.updated_at,
      user: {
        id: document.user.id,
        email: document.user.email,
        full_name: document.user.full_name,
        role: document.user.role
      },
      embeddings_count: document.embeddings.count
    }
  end
end
