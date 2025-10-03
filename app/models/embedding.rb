class Embedding < ApplicationRecord
  belongs_to :document

  validates :chunk_text, presence: true
  validates :chunk_index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :embedding, presence: true
  validates :embedding_model, presence: true

  scope :by_document, ->(document) { where(document: document) }
  scope :ordered, -> { order(:chunk_index) }

  def embedding_vector
    @embedding_vector ||= JSON.parse(embedding)
  end

  def embedding_vector=(vector)
    self.embedding = vector.to_json
    @embedding_vector = vector
  end

  def self.find_similar(query_embedding, limit: 10)
    query_vector = query_embedding.is_a?(String) ? JSON.parse(query_embedding) : query_embedding

    all.map do |emb|
      {
        embedding: emb,
        similarity: cosine_similarity(query_vector, emb.embedding_vector)
      }
    end.sort_by { |result| -result[:similarity] }.first(limit)
  end

  def self.cosine_similarity(vec1, vec2)
    dot_product = vec1.zip(vec2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(vec1.sum { |a| a**2 })
    magnitude2 = Math.sqrt(vec2.sum { |a| a**2 })

    return 0 if magnitude1.zero? || magnitude2.zero?

    dot_product / (magnitude1 * magnitude2)
  end
end
