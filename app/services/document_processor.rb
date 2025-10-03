class DocumentProcessor
  def self.process(document)
    new(document).process
  end

  def initialize(document)
    @document = document
    @ollama = OllamaService.new
  end

  def process
    return false unless @document.pending? || @document.failed?

    @document.mark_as_processing!

    text = DocumentParser.parse(@document.file_path, @document.file_type)

    chunks = TextChunker.chunk(text)

    chunks.each do |chunk|
      embedding_vector = @ollama.generate_embedding(chunk[:text])

      @document.embeddings.create!(
        chunk_text: chunk[:text],
        chunk_index: chunk[:index],
        embedding: embedding_vector.to_json,
        embedding_model: OllamaService::DEFAULT_MODEL
      )
    end

    @document.mark_as_completed!
    true
  rescue => e
    @document.mark_as_failed!
    Rails.logger.error "Document processing failed for #{@document.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end
end
