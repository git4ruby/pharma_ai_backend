class SemanticSearch
  CHUNK_SIZE = 1000 # characters per chunk
  CHUNK_OVERLAP = 200 # overlap between chunks

  def self.search(question, limit: 5, user: nil)
    new(question, limit: limit, user: user).search
  end

  def self.generate_embeddings(document, text)
    new(nil).generate_embeddings_for_document(document, text)
  end

  def initialize(question, limit: 5, user: nil)
    @question = question
    @limit = limit
    @user = user
    @ollama = OllamaService.new
  end

  def search
    query_embedding = @ollama.generate_embedding(@question)

    # Get user's accessible documents
    accessible_doc_ids = get_accessible_document_ids

    results = Embedding.find_similar(query_embedding, limit: @limit, document_ids: accessible_doc_ids)

    results.map do |result|
      {
        embedding: result[:embedding],
        document: result[:embedding].document,
        similarity: result[:similarity],
        chunk_text: result[:embedding].chunk_text,
        chunk_index: result[:embedding].chunk_index
      }
    end
  end

  def generate_embeddings_for_document(document, text)
    chunks = chunk_text(text)

    Rails.logger.info "Generating embeddings for #{chunks.length} chunks"

    chunks.each_with_index do |chunk_text, index|
      # Generate embedding for this chunk
      embedding_vector = @ollama.generate_embedding(chunk_text)

      # Store embedding in database
      Embedding.create!(
        document: document,
        chunk_text: chunk_text,
        chunk_index: index,
        embedding_vector: embedding_vector,
        embedding_model: OllamaService::DEFAULT_EMBEDDING_MODEL
      )

      Rails.logger.info "Created embedding #{index + 1}/#{chunks.length} for document #{document.id}"
    end

    Rails.logger.info "Successfully created #{chunks.length} embeddings for document #{document.id}"
  end

  private

  def get_accessible_document_ids
    return Document.pluck(:id) if @user.nil? # No user filter if not provided
    return Document.pluck(:id) if @user.admin? # Admin can see all documents
    return Document.pluck(:id) if @user.auditor? # Auditor can see all documents for compliance

    # Get user's own documents
    accessible_ids = @user.documents.pluck(:id)

    # Doctors and Researchers can also access drug information (non-PHI public medical knowledge)
    if @user.doctor? || @user.researcher?
      drug_info_ids = Document.where("title LIKE ?", "%drug info%").pluck(:id)
      accessible_ids = (accessible_ids + drug_info_ids).uniq
    end

    accessible_ids
  end

  def chunk_text(text)
    return [] if text.blank?

    chunks = []
    start_pos = 0

    while start_pos < text.length
      end_pos = [start_pos + CHUNK_SIZE, text.length].min

      # Try to break at sentence boundary if possible
      if end_pos < text.length
        last_period = text.rindex(/[.!?]\s/, end_pos)
        end_pos = last_period + 1 if last_period && last_period > start_pos
      end

      chunk = text[start_pos...end_pos].strip
      chunks << chunk unless chunk.empty?

      # Move forward with overlap
      # BUT if we've reached the end of the text, exit loop
      if end_pos >= text.length
        start_pos = text.length
      else
        start_pos = end_pos - CHUNK_OVERLAP
        start_pos = end_pos if start_pos < 0
      end
    end

    chunks
  end
end
