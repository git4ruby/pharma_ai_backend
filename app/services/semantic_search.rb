class SemanticSearch
  def self.search(question, limit: 5)
    new(question, limit: limit).search
  end

  def initialize(question, limit: 5)
    @question = question
    @limit = limit
    @ollama = OllamaService.new
  end

  def search
    query_embedding = @ollama.generate_embedding(@question)

    results = Embedding.find_similar(query_embedding, limit: @limit)

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
end
