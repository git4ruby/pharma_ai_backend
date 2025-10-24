# Asclepius AI Backend

A Ruby on Rails API backend for pharmaceutical document management with AI-powered semantic search and Q&A capabilities.

## Overview

Asclepius AI Backend provides a secure, HIPAA-compliant REST API for managing pharmaceutical documents, user authentication, role-based access control, and AI-powered document querying. The system integrates with Ollama for local AI inference and natural language processing, and uses background jobs for asynchronous document processing.

## Features

### Core Functionality
- **Document Management**: Upload, store, and manage pharmaceutical documents
- **AI-Powered Q&A**: Semantic search and natural language querying with Ollama
- **Background Processing**: Asynchronous document processing with Sidekiq
- **File Storage**: Active Storage with local/cloud storage support
- **API-Only Architecture**: RESTful JSON API for frontend integration

### Security & Compliance
- **Authentication**: Devise with JWT token-based authentication
- **Authorization**: Role-based access control (RBAC) with 4 user roles
- **Session Management**: Redis-backed session storage
- **Audit Logging**: Comprehensive activity logging for compliance
- **PHI Protection**: HIPAA-compliant Protected Health Information handling
- **CORS Configuration**: Secure cross-origin resource sharing

### Admin Features
- **User Management**: CRUD operations for user accounts and roles
- **Analytics**: System usage statistics and metrics
- **Compliance Monitoring**: HIPAA compliance status tracking
- **Background Jobs**: Sidekiq job monitoring and management
- **Audit Trails**: Detailed activity logs with retention policies

## Technology Stack

- **Framework**: Ruby on Rails 7.2 (API-only mode)
- **Ruby Version**: 3.2+
- **Database**: PostgreSQL 14+
- **Cache/Queue**: Redis 7+
- **Background Jobs**: Sidekiq
- **Authentication**: Devise + JWT
- **AI Integration**: Ollama (Local LLM inference)
- **File Storage**: Active Storage

## Prerequisites

- Ruby 3.2 or higher
- PostgreSQL 14+
- Redis 7+
- Ollama installed and running locally

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd pharma_ai_backend
```

2. Install dependencies:
```bash
bundle install
```

3. Set up environment variables:
```bash
# Create .env file
cp .env.example .env

# Configure required variables
DATABASE_URL=postgresql://localhost/pharma_ai_development
REDIS_URL=redis://localhost:6379/0
OLLAMA_URL=http://localhost:11434
SECRET_KEY_BASE=your_secret_key
```

4. Create and setup database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

5. Start Redis (if not running):
```bash
redis-server
```

6. Start Sidekiq:
```bash
bundle exec sidekiq
```

7. Start the Rails server:
```bash
rails server -p 3000
```

The API will be available at `http://localhost:3000`

## Database Setup

### Running Migrations
```bash
rails db:migrate
```

### Seeding Data
```bash
rails db:seed
```

The seed file creates:
- Default admin user (check `db/seeds.rb` for credentials)
- Sample documents (optional)
- Initial configuration data

### Reset Database
```bash
rails db:reset  # Drops, creates, migrates, and seeds
```

## API Documentation

### Authentication

#### Signup
```bash
POST /api/auth/signup
Content-Type: application/json

{
  "user": {
    "email": "user@example.com",
    "password": "password123",
    "full_name": "John Doe",
    "role": "researcher"
  }
}
```

#### Login
```bash
POST /api/auth/login
Content-Type: application/json

{
  "user": {
    "email": "user@example.com",
    "password": "password123"
  }
}
```

Response includes JWT token in Authorization header.

### Documents

#### Upload Document
```bash
POST /api/documents
Authorization: Bearer <token>
Content-Type: multipart/form-data

{
  "document": {
    "title": "Clinical Trial Results",
    "classification": "confidential",
    "contains_phi": false,
    "file": <file_upload>
  }
}
```

#### List Documents
```bash
GET /api/documents
Authorization: Bearer <token>
```

#### Get Document
```bash
GET /api/documents/:id
Authorization: Bearer <token>
```

#### Delete Document
```bash
DELETE /api/documents/:id
Authorization: Bearer <token>
```

### Queries

#### Ask Question
```bash
POST /api/queries
Authorization: Bearer <token>
Content-Type: application/json

{
  "query": {
    "question": "What are the side effects of Drug X?"
  }
}
```

#### List Queries
```bash
GET /api/queries
Authorization: Bearer <token>
```

### Admin Endpoints

#### User Management
```bash
GET /api/users              # List all users
POST /api/users             # Create user
PATCH /api/users/:id/role   # Update user role
DELETE /api/users/:id       # Delete user
```

#### Analytics
```bash
GET /api/analytics/dashboard
```

#### Audit Logs
```bash
GET /api/audit-logs
```

#### Background Jobs
```bash
GET /api/admin/background_jobs/stats
GET /api/admin/background_jobs/queues
GET /api/admin/background_jobs/failed
POST /api/admin/background_jobs/:jid/retry
DELETE /api/admin/background_jobs/:jid
```

## User Roles

### Admin
- Full system access
- User management (CRUD)
- All document access
- System configuration
- Analytics and audit logs

### Auditor
- Read-only access to query audits
- View all queries and responses
- Access to compliance reports
- No document upload/modification

### Researcher
- Upload and manage own documents
- Query all accessible documents
- View own documents and public documents
- Limited analytics

### Doctor
- Upload and manage own documents
- Query all accessible documents
- Access to PHI documents (only uploaded by them)
- Full analytics access

## Background Jobs

### Sidekiq Configuration

Jobs are processed in different queues:
- **default**: General background tasks
- **critical**: High-priority operations
- **document_processing**: AI document processing

Monitor jobs:
```bash
# View Sidekiq web interface
# Add to config/routes.rb:
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

### Document Processing Worker

Documents are processed asynchronously:
```ruby
DocumentProcessingWorker.perform_async(document_id)
```

Processing includes:
- Content extraction (PDF, DOCX, TXT)
- AI embedding generation
- Metadata extraction
- Status updates

## Testing

### Run all tests
```bash
bundle exec rspec
```

### Run specific test file
```bash
bundle exec rspec spec/models/user_spec.rb
```

### Run with coverage
```bash
COVERAGE=true bundle exec rspec
```

Coverage reports are generated in `coverage/` directory.

## Development

### Console
```bash
rails console
```

### Routes
```bash
rails routes
```

### Database Console
```bash
rails dbconsole
```

### Code Quality
```bash
# Run Rubocop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

## Project Structure

```
app/
├── controllers/
│   └── api/
│       ├── auth/                 # Authentication controllers
│       ├── admin/                # Admin-only controllers
│       ├── documents_controller.rb
│       ├── queries_controller.rb
│       └── ...
├── models/
│   ├── user.rb                   # User model with Devise
│   ├── document.rb               # Document model
│   ├── query.rb                  # Query model
│   └── audit_log.rb              # Audit logging
├── services/
│   ├── ollama_service.rb         # Ollama AI integration
│   ├── document_processor.rb    # Document processing logic
│   └── access_control_service.rb # RBAC logic
├── workers/
│   └── document_processing_worker.rb  # Sidekiq workers
└── serializers/                  # JSON serializers

config/
├── database.yml                  # Database configuration
├── routes.rb                     # API routes
├── initializers/
│   ├── cors.rb                   # CORS configuration
│   ├── devise.rb                 # Authentication
│   └── sidekiq.rb               # Background jobs
└── application.rb                # Rails configuration

db/
├── migrate/                      # Database migrations
└── seeds.rb                      # Seed data
```

## Environment Variables

```env
# Database
DATABASE_URL=postgresql://localhost/pharma_ai_development

# Redis
REDIS_URL=redis://localhost:6379/0

# Rails
SECRET_KEY_BASE=your_secret_key_base
RAILS_ENV=development

# Ollama
OLLAMA_URL=http://localhost:11434

# CORS
ALLOWED_ORIGINS=http://localhost:4000

# File Storage (for production)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_REGION=us-east-1
AWS_BUCKET=pharma-ai-documents
```

## Deployment

### Prerequisites
- PostgreSQL database
- Redis instance
- Ollama installed and running
- Cloud storage (AWS S3, etc.)

### Steps

1. Set environment variables on your platform
2. Run database migrations:
```bash
rails db:migrate RAILS_ENV=production
```

3. Precompile assets (if any):
```bash
rails assets:precompile
```

4. Start Sidekiq workers:
```bash
bundle exec sidekiq -e production
```

5. Start Rails server:
```bash
rails server -e production
```

## Security Considerations

### PHI Protection
- PHI documents are only accessible by uploader and admins
- All PHI access is logged in audit logs
- Encryption at rest for file storage
- Secure transmission over HTTPS

### Access Control
- JWT token expiration: 24 hours
- Session timeout: 15 minutes of inactivity
- Password requirements: Minimum 8 characters
- Failed login attempt tracking

### Compliance
- Audit log retention: 7 years
- Automated compliance reporting
- Data encryption in transit and at rest
- Regular security audits

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL is running
psql -l

# Reset database connection
rails db:reset
```

### Redis Connection Issues
```bash
# Check Redis is running
redis-cli ping

# Should return: PONG
```

### Sidekiq Not Processing Jobs
```bash
# Check Sidekiq status
ps aux | grep sidekiq

# Restart Sidekiq
pkill -9 sidekiq
bundle exec sidekiq
```

### Ollama Connection Issues
```bash
# Check Ollama is running
curl http://localhost:11434/api/version

# Start Ollama
ollama serve
```

- Verify Ollama is installed: `ollama --version`
- Ensure required models are pulled: `ollama pull llama2`
- Check Ollama logs for errors

## Contributing

1. Create a feature branch
2. Make your changes
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Testing Strategy

- **Unit Tests**: Models, services, workers
- **Integration Tests**: API endpoints, authentication
- **Request Specs**: Full request/response cycles
- **Test Coverage**: Aim for 80%+ coverage

## License

MIT License - see LICENSE file for details

## Additional Resources

- [Rails API Documentation](https://guides.rubyonrails.org/api_app.html)
- [Devise Documentation](https://github.com/heartcombo/devise)
- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq)
- [Ollama Documentation](https://github.com/ollama/ollama)
