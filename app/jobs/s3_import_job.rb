require 'aws-sdk-s3'

class S3ImportJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting scheduled S3 import check..."

    begin
      result = import_from_s3

      if result[:imported_count] > 0
        Rails.logger.info "S3 import completed: #{result[:imported_count]} new documents imported"
      else
        Rails.logger.info "S3 import check completed: No new documents found"
      end

      result
    rescue => e
      Rails.logger.error "S3 import failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def import_from_s3
    s3_client = Aws::S3::Client.new(
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )

    bucket_name = ENV['AWS_S3_BUCKET']

    # List all objects in the bucket
    response = s3_client.list_objects_v2(bucket: bucket_name)

    imported_count = 0
    skipped_count = 0
    failed_count = 0

    # Get the S3 System user
    s3_user = User.find_by(email: 's3-system@asclepius-ai.com')
    unless s3_user
      raise "S3 System user not found. Please run 'rails db:seed' first."
    end

    response.contents.each do |object|
      key = object.key

      # Skip if not a supported file type
      next unless key.match?(/\.(pdf|docx|txt)$/i)

      # Get file info
      head_response = s3_client.head_object(bucket: bucket_name, key: key)
      content_type = head_response.content_type
      file_size = head_response.content_length

      # Skip if file type not supported
      unless Document::ALLOWED_FILE_TYPES.include?(content_type)
        skipped_count += 1
        next
      end

      # Download file content to calculate hash
      obj = s3_client.get_object(bucket: bucket_name, key: key)
      file_content = obj.body.read
      content_hash = Digest::SHA256.hexdigest(file_content)

      # Check if document already exists
      if Document.exists?(content_hash: content_hash)
        skipped_count += 1
        next
      end

      # Extract filename from key (last part of path)
      filename = File.basename(key)
      title = filename.gsub(File.extname(filename), '')

      # Create document record
      document = Document.new(
        user: s3_user,
        title: title,
        filename: filename,
        file_path: "active_storage",
        file_type: content_type,
        file_size: file_size,
        content_hash: content_hash,
        contains_phi: false,
        classification: 'public',
        status: 'pending'
      )

      # Attach the file from S3
      document.file.attach(
        io: StringIO.new(file_content),
        filename: filename,
        content_type: content_type
      )

      if document.save
        # Enqueue processing job
        DocumentProcessorJob.perform_later(document.id)

        Rails.logger.info "Imported document from S3: #{filename}"
        imported_count += 1
      else
        Rails.logger.error "Failed to import document: #{filename} - #{document.errors.full_messages.join(', ')}"
        failed_count += 1
      end

    rescue => e
      Rails.logger.error "Failed to process S3 object #{key}: #{e.message}"
      failed_count += 1
    end

    {
      imported_count: imported_count,
      skipped_count: skipped_count,
      failed_count: failed_count
    }
  end
end
