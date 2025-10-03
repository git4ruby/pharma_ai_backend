class Query < ApplicationRecord
  belongs_to :user
  has_many :citations, dependent: :destroy
  has_many :documents, through: :citations
  has_many :embeddings, through: :citations

  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  validates :question, presence: true, length: { minimum: 3, maximum: 1000 }
  validates :status, presence: true

  scope :recent, -> { order(queried_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :successful, -> { where(status: 'completed') }

  def mark_as_processing!
    update!(status: 'processing')
  end

  def mark_as_completed!(answer_text, time_taken)
    update!(
      status: 'completed',
      answer: answer_text,
      processing_time: time_taken
    )
  end

  def mark_as_failed!
    update!(status: 'failed')
  end

  def add_citation(document:, embedding:, score:)
    citations.create!(
      document: document,
      embedding: embedding,
      relevance_score: score
    )
  end

  def top_citations(limit = 5)
    citations.order(relevance_score: :desc).limit(limit)
  end
end
