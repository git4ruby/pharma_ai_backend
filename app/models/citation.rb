class Citation < ApplicationRecord
  belongs_to :query
  belongs_to :document
  belongs_to :embedding

  validates :relevance_score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  scope :ordered_by_relevance, -> { order(relevance_score: :desc) }
  scope :high_relevance, -> { where('relevance_score >= ?', 0.7) }
end
