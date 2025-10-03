class OllamaService
  class ConnectionError < StandardError; end
  class GenerationError < StandardError; end

  OLLAMA_HOST = ENV.fetch('OLLAMA_HOST', 'http://localhost:11434')
  DEFAULT_MODEL = 'llama3.2:3b'

  def initialize(model: DEFAULT_MODEL)
    @model = model
    @base_url = OLLAMA_HOST
  end

  def generate_embedding(text)
    response = HTTParty.post(
      "#{@base_url}/api/embeddings",
      body: {
        model: @model,
        prompt: text
      }.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 30
    )

    unless response.success?
      raise GenerationError, "Ollama API error: #{response.code} - #{response.body}"
    end

    parsed = JSON.parse(response.body)
    parsed['embedding']
  rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
    raise ConnectionError, "Failed to connect to Ollama: #{e.message}"
  rescue JSON::ParserError => e
    raise GenerationError, "Invalid response from Ollama: #{e.message}"
  end

  def generate_answer(question, context)
    prompt = build_qa_prompt(question, context)

    response = HTTParty.post(
      "#{@base_url}/api/generate",
      body: {
        model: @model,
        prompt: prompt,
        stream: false
      }.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 60
    )

    unless response.success?
      raise GenerationError, "Ollama API error: #{response.code} - #{response.body}"
    end

    parsed = JSON.parse(response.body)
    parsed['response']
  rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
    raise ConnectionError, "Failed to connect to Ollama: #{e.message}"
  rescue JSON::ParserError => e
    raise GenerationError, "Invalid response from Ollama: #{e.message}"
  end

  def check_connection
    response = HTTParty.get("#{@base_url}/api/tags", timeout: 5)
    response.success?
  rescue
    false
  end

  private

  def build_qa_prompt(question, context)
    <<~PROMPT
      You are a helpful AI assistant for pharmaceutical research. Answer the question based on the provided context.

      Context:
      #{context}

      Question: #{question}

      Instructions:
      - Answer based only on the provided context
      - Be concise and factual
      - If the context doesn't contain enough information, say so
      - Cite specific details from the context when possible

      Answer:
    PROMPT
  end
end
