class DocumentParser
  class UnsupportedFileType < StandardError; end
  class ParsingError < StandardError; end

  # New method that accepts a Document object
  def self.parse_document(document)
    new_from_document(document).parse
  end

  # Legacy method for backward compatibility
  def self.parse(file_path, file_type)
    new(file_path, file_type).parse
  end

  def self.new_from_document(document)
    instance = allocate
    instance.instance_variable_set(:@document, document)
    instance.instance_variable_set(:@file_type, document.file_type)
    instance.instance_variable_set(:@use_active_storage, document.file.attached?)
    instance.instance_variable_set(:@file_path, document.file_path) unless document.file.attached?
    instance
  end

  def initialize(file_path, file_type)
    @file_path = file_path
    @file_type = file_type
    @use_active_storage = false
  end

  def parse
    # Download file from Active Storage if needed
    if @use_active_storage
      @document.file.open do |file|
        @temp_file_path = file.path
        return parse_file
      end
    else
      raise ParsingError, "File not found: #{@file_path}" unless File.exist?(@file_path)
      @temp_file_path = @file_path
      return parse_file
    end
  rescue => e
    raise ParsingError, "Failed to parse document: #{e.message}"
  end

  private

  def parse_file
    case @file_type
    when 'application/pdf'
      parse_pdf
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      parse_docx
    when 'text/plain'
      parse_text
    else
      raise UnsupportedFileType, "Unsupported file type: #{@file_type}"
    end
  end

  def parse_pdf
    require 'pdf-reader'

    reader = PDF::Reader.new(@temp_file_path)
    text = reader.pages.map(&:text).join("\n\n")

    clean_text(text)
  end

  def parse_docx
    require 'docx'

    doc = Docx::Document.open(@temp_file_path)
    text = doc.paragraphs.map(&:text).join("\n")

    clean_text(text)
  end

  def parse_text
    File.read(@temp_file_path, encoding: 'UTF-8')
  end

  def clean_text(text)
    text
      .gsub(/\r\n/, "\n")
      .gsub(/\r/, "\n")
      .gsub(/\n{3,}/, "\n\n")
      .gsub(/[ \t]+/, ' ')
      .strip
  end
end
