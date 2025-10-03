class DocumentParser
  class UnsupportedFileType < StandardError; end
  class ParsingError < StandardError; end

  def self.parse(file_path, file_type)
    new(file_path, file_type).parse
  end

  def initialize(file_path, file_type)
    @file_path = file_path
    @file_type = file_type
  end

  def parse
    raise ParsingError, "File not found: #{@file_path}" unless File.exist?(@file_path)

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
  rescue => e
    raise ParsingError, "Failed to parse document: #{e.message}"
  end

  private

  def parse_pdf
    require 'pdf-reader'

    reader = PDF::Reader.new(@file_path)
    text = reader.pages.map(&:text).join("\n\n")

    clean_text(text)
  end

  def parse_docx
    require 'docx'

    doc = Docx::Document.open(@file_path)
    text = doc.paragraphs.map(&:text).join("\n")

    clean_text(text)
  end

  def parse_text
    File.read(@file_path, encoding: 'UTF-8')
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
