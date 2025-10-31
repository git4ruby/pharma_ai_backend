namespace :storage do
  desc "Migrate existing local files to AWS S3"
  task migrate_to_s3: :environment do
    puts "\n==== Starting S3 Migration ===="
    puts "This task will migrate all locally stored Active Storage files to AWS S3"

    # Check AWS credentials are configured
    unless ENV['AWS_ACCESS_KEY_ID'].present? &&
           ENV['AWS_SECRET_ACCESS_KEY'].present? &&
           ENV['AWS_S3_BUCKET'].present?
      puts "\n❌ ERROR: AWS credentials not configured!"
      puts "Please set the following environment variables in .env:"
      puts "  - AWS_ACCESS_KEY_ID"
      puts "  - AWS_SECRET_ACCESS_KEY"
      puts "  - AWS_REGION"
      puts "  - AWS_S3_BUCKET"
      exit 1
    end

    puts "\nAWS Configuration:"
    puts "  Region: #{ENV['AWS_REGION']}"
    puts "  Bucket: #{ENV['AWS_S3_BUCKET']}"

    # Count total files to migrate
    blobs_with_local_service = ActiveStorage::Blob.where(service_name: 'local')
    total_count = blobs_with_local_service.count

    if total_count.zero?
      puts "\n✓ No local files to migrate. All files are already on S3."
      exit 0
    end

    puts "\n📁 Found #{total_count} files to migrate"
    print "\nProceed with migration? (yes/no): "

    # In rake tasks, we need to get input from STDIN
    confirmation = STDIN.gets.chomp.downcase

    unless confirmation == 'yes'
      puts "\n❌ Migration cancelled by user"
      exit 0
    end

    puts "\n🚀 Starting migration...\n"

    migrated_count = 0
    failed_count = 0
    failed_files = []

    blobs_with_local_service.find_each.with_index do |blob, index|
      begin
        # Download the file from local storage
        file_content = blob.download

        # Create a new blob on S3 with the same attributes
        new_blob = ActiveStorage::Blob.create!(
          key: blob.key,
          filename: blob.filename,
          content_type: blob.content_type,
          metadata: blob.metadata,
          service_name: 'amazon',
          byte_size: blob.byte_size,
          checksum: blob.checksum
        )

        # Upload to S3
        new_blob.upload(StringIO.new(file_content))

        # Update all attachments to point to the new blob
        ActiveStorage::Attachment.where(blob_id: blob.id).update_all(blob_id: new_blob.id)

        # Delete the old blob (this also deletes the local file)
        blob.destroy

        migrated_count += 1
        progress = ((index + 1).to_f / total_count * 100).round(1)
        puts "  [#{progress}%] ✓ Migrated: #{blob.filename} (#{blob.byte_size} bytes)"

      rescue => e
        failed_count += 1
        failed_files << { filename: blob.filename, error: e.message }
        puts "  [#{((index + 1).to_f / total_count * 100).round(1)}%] ✗ Failed: #{blob.filename} - #{e.message}"
      end
    end

    puts "\n==== Migration Complete ===="
    puts "✓ Successfully migrated: #{migrated_count} files"

    if failed_count > 0
      puts "✗ Failed to migrate: #{failed_count} files"
      puts "\nFailed files:"
      failed_files.each do |file|
        puts "  - #{file[:filename]}: #{file[:error]}"
      end
    end

    puts "\n📊 Storage Summary:"
    puts "  Local files remaining: #{ActiveStorage::Blob.where(service_name: 'local').count}"
    puts "  S3 files: #{ActiveStorage::Blob.where(service_name: 'amazon').count}"
    puts "  Total files: #{ActiveStorage::Blob.count}"
  end

  desc "Import documents from S3 bucket (for files uploaded directly to S3)"
  task import_from_s3: :environment do
    puts "\n==== Import Documents from S3 ===="
    puts "This task will scan your S3 bucket and import any documents not yet in the database"

    # Check AWS credentials
    unless ENV['AWS_ACCESS_KEY_ID'].present? &&
           ENV['AWS_SECRET_ACCESS_KEY'].present? &&
           ENV['AWS_S3_BUCKET'].present?
      puts "\n❌ ERROR: AWS credentials not configured!"
      exit 1
    end

    # Find or create S3 System User
    s3_user = User.find_by(email: 's3-system@asclepius-ai.com')

    unless s3_user
      puts "\n❌ ERROR: S3 System User not found!"
      puts "Please run: rails db:seed"
      exit 1
    end

    puts "\n✓ S3 System User found: #{s3_user.email}"
    puts "  Documents imported from S3 will be assigned to this user"

    require 'aws-sdk-s3'

    begin
      # Initialize S3 client
      s3_client = Aws::S3::Client.new(
        region: ENV['AWS_REGION'],
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )

      bucket_name = ENV['AWS_S3_BUCKET']

      puts "\n📦 Scanning S3 bucket: #{bucket_name}"

      # List all objects in bucket
      objects = []
      s3_client.list_objects_v2(bucket: bucket_name).each do |response|
        objects.concat(response.contents)
      end

      puts "   Found #{objects.count} objects in S3 bucket"

      imported_count = 0
      skipped_count = 0

      objects.each do |object|
        # Skip if already exists in database
        existing_blob = ActiveStorage::Blob.find_by(key: object.key)

        if existing_blob
          skipped_count += 1
          puts "  ⊘ Skipped (already exists): #{object.key}"
          next
        end

        # Import the file
        begin
          # Create blob record
          blob = ActiveStorage::Blob.create!(
            key: object.key,
            filename: File.basename(object.key),
            content_type: 'application/octet-stream',  # S3 doesn't store content type
            metadata: { imported_from_s3: true, original_key: object.key },
            service_name: 'amazon',
            byte_size: object.size,
            checksum: object.etag.gsub('"', '')
          )

          # Create document record
          document = Document.create!(
            user: s3_user,
            title: File.basename(object.key, '.*').humanize,
            filename: File.basename(object.key),
            file_type: 'application/octet-stream',
            file_size: object.size,
            contains_phi: false,  # Default to false, admin can update
            classification: 'public',  # Default to public, admin can update
            status: 'pending'
          )

          # Attach blob to document
          document.file.attach(blob)

          imported_count += 1
          puts "  ✓ Imported: #{object.key} (#{object.size} bytes) → Document ##{document.id}"

        rescue => e
          puts "  ✗ Failed to import #{object.key}: #{e.message}"
        end
      end

      puts "\n==== Import Complete ===="
      puts "✓ Imported: #{imported_count} documents"
      puts "⊘ Skipped (already exists): #{skipped_count} documents"
      puts "\n💡 Note: Imported documents have default classification (public, no PHI)"
      puts "   Please review and update classifications as needed in the admin panel"

    rescue Aws::S3::Errors::ServiceError => e
      puts "\n❌ S3 Error: #{e.message}"
      exit 1
    end
  end

  desc "Check migration status"
  task status: :environment do
    puts "\n==== Storage Status ===="

    total_blobs = ActiveStorage::Blob.count
    local_blobs = ActiveStorage::Blob.where(service_name: 'local').count
    s3_blobs = ActiveStorage::Blob.where(service_name: 'amazon').count

    puts "📊 Active Storage Blobs:"
    puts "  Total: #{total_blobs}"
    puts "  Local storage: #{local_blobs} (#{total_blobs > 0 ? (local_blobs.to_f / total_blobs * 100).round(1) : 0}%)"
    puts "  S3 storage: #{s3_blobs} (#{total_blobs > 0 ? (s3_blobs.to_f / total_blobs * 100).round(1) : 0}%)"

    total_documents = Document.count
    puts "\n📄 Documents:"
    puts "  Total: #{total_documents}"

    s3_user = User.find_by(email: 's3-system@asclepius-ai.com')
    if s3_user
      s3_imported_docs = Document.where(user: s3_user).count
      puts "  Imported from S3: #{s3_imported_docs}"
    else
      puts "  ⚠️  S3 System User not found (run: rails db:seed)"
    end

    puts "\n⚙️  Current Configuration:"
    puts "  Development: #{Rails.application.config.active_storage.service}"

    if ENV['AWS_ACCESS_KEY_ID'].present?
      puts "  AWS Region: #{ENV['AWS_REGION']}"
      puts "  AWS Bucket: #{ENV['AWS_S3_BUCKET']}"
    else
      puts "  ⚠️  AWS credentials not configured"
    end
  end
end
