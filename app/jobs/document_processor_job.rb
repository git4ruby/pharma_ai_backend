class DocumentProcessorJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)

    Rails.logger.info "Processing document #{document.id}: #{document.title}"

    begin
      # Update status to processing
      document.update!(status: 'processing')

      # Parse document to extract text
      text = DocumentParser.parse(document.file_path, document.file_type)

      Rails.logger.info "Extracted #{text.length} characters from document #{document.id}"

      # Generate embeddings using SemanticSearch
      Rails.logger.info "Starting embedding generation for document #{document.id}"
      SemanticSearch.generate_embeddings(document, text)
      Rails.logger.info "Finished embedding generation for document #{document.id}"

      # Update status to completed
      document.update!(status: 'completed', processed_at: Time.current)

      Rails.logger.info "Successfully processed document #{document.id} with #{document.embeddings.count} embeddings"
    rescue => e
      Rails.logger.error "Failed to process document #{document.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      document.update!(status: 'failed')
      raise e
    end
  end
end
