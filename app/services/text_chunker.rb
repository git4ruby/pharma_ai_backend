class TextChunker
  DEFAULT_CHUNK_SIZE = 800
  DEFAULT_OVERLAP = 100

  def self.chunk(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
    new(text, chunk_size: chunk_size, overlap: overlap).chunk
  end

  def initialize(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
    @text = text
    @chunk_size = chunk_size
    @overlap = overlap
  end

  def chunk
    return [] if @text.blank?

    chunks = []
    paragraphs = @text.split(/\n\n+/)

    current_chunk = ""
    current_size = 0

    paragraphs.each do |paragraph|
      paragraph = paragraph.strip
      next if paragraph.empty?

      paragraph_size = paragraph.length

      if current_size + paragraph_size + 2 <= @chunk_size
        current_chunk += "\n\n" unless current_chunk.empty?
        current_chunk += paragraph
        current_size = current_chunk.length
      else
        chunks << current_chunk.strip unless current_chunk.empty?

        if paragraph_size > @chunk_size
          chunks.concat(split_large_paragraph(paragraph))
          current_chunk = ""
          current_size = 0
        else
          overlap_text = extract_overlap(current_chunk)
          current_chunk = overlap_text.empty? ? paragraph : "#{overlap_text}\n\n#{paragraph}"
          current_size = current_chunk.length
        end
      end
    end

    chunks << current_chunk.strip unless current_chunk.empty?

    chunks.map.with_index do |chunk_text, index|
      {
        text: chunk_text,
        index: index,
        size: chunk_text.length
      }
    end
  end

  private

  def split_large_paragraph(paragraph)
    words = paragraph.split(/\s+/)
    chunks = []
    current_chunk = []
    current_size = 0

    words.each do |word|
      word_size = word.length + 1

      if current_size + word_size > @chunk_size
        chunks << current_chunk.join(' ') unless current_chunk.empty?

        overlap_words = current_chunk.last([(@overlap / 10).to_i, 5].max)
        current_chunk = overlap_words + [word]
        current_size = current_chunk.join(' ').length
      else
        current_chunk << word
        current_size += word_size
      end
    end

    chunks << current_chunk.join(' ') unless current_chunk.empty?
    chunks
  end

  def extract_overlap(text)
    return "" if text.length <= @overlap

    sentences = text.split(/(?<=[.!?])\s+/)
    overlap_text = ""

    sentences.reverse_each do |sentence|
      if (overlap_text.length + sentence.length + 1) <= @overlap
        overlap_text = sentence + (overlap_text.empty? ? "" : " #{overlap_text}")
      else
        break
      end
    end

    overlap_text
  end
end
