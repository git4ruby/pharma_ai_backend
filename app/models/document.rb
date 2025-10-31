class Document < ApplicationRecord
  belongs_to :user
  has_many :embeddings, dependent: :destroy
  has_many :citations, dependent: :destroy
  has_many :queries, through: :citations

  # Active Storage attachment for S3
  has_one_attached :file

  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }

  ALLOWED_FILE_TYPES = %w[application/pdf application/vnd.openxmlformats-officedocument.wordprocessingml.document text/plain].freeze
  MAX_FILE_SIZE = 50.megabytes

  validates :title, presence: true, length: { maximum: 255 }
  validates :filename, presence: true
  # file_path is now optional (legacy field, kept for backward compatibility)
  validates :file_type, presence: true, inclusion: { in: ALLOWED_FILE_TYPES }
  validates :file_size, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: MAX_FILE_SIZE }
  validates :content_hash, presence: true, uniqueness: true
  validates :status, presence: true

  scope :with_phi, -> { where(contains_phi: true) }
  scope :without_phi, -> { where(contains_phi: false) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :processed, -> { where(status: 'completed') }

  def file_extension
    File.extname(filename).delete('.')
  end

  def human_file_size
    ActiveSupport::NumberHelper.number_to_human_size(file_size)
  end

  def mark_as_processing!
    update!(status: 'processing')
  end

  def mark_as_completed!
    update!(status: 'completed', processed_at: Time.current)
  end

  def mark_as_failed!
    update!(status: 'failed')
  end
end
