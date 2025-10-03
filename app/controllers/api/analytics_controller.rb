module Api
  class AnalyticsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin

    # GET /api/analytics/dashboard
    def dashboard
      analytics_data = {
        overview: {
          total_users: User.count,
          total_documents: Document.count,
          total_queries: Query.count,
          total_embeddings: Embedding.count
        },
        user_statistics: {
          by_role: User.group(:role).count,
          active_users_7d: active_users_count(7.days.ago),
          active_users_30d: active_users_count(30.days.ago),
          new_users_7d: User.where('created_at > ?', 7.days.ago).count,
          new_users_30d: User.where('created_at > ?', 30.days.ago).count
        },
        document_statistics: {
          by_status: Document.group(:status).count,
          by_file_type: Document.group(:file_type).count,
          total_storage_bytes: Document.sum(:file_size),
          avg_document_size: Document.average(:file_size)&.round(2),
          documents_uploaded_7d: Document.where('created_at > ?', 7.days.ago).count,
          documents_uploaded_30d: Document.where('created_at > ?', 30.days.ago).count,
          top_uploaders: top_document_uploaders(5)
        },
        query_statistics: {
          by_status: Query.group(:status).count,
          total_queries_7d: Query.where('created_at > ?', 7.days.ago).count,
          total_queries_30d: Query.where('created_at > ?', 30.days.ago).count,
          avg_processing_time: Query.where(status: 'completed').average(:processing_time)&.round(2),
          top_queriers: top_queriers(5),
          queries_with_citations: Query.joins(:citations).distinct.count
        },
        embedding_statistics: {
          total_embeddings: Embedding.count,
          embeddings_by_model: Embedding.group(:embedding_model).count,
          avg_embeddings_per_document: (Embedding.count.to_f / Document.count).round(2),
          documents_with_embeddings: Document.joins(:embeddings).distinct.count
        },
        security_metrics: {
          failed_logins_24h: AuditLog.where(action: 'user.failed_login').where('created_at > ?', 24.hours.ago).count,
          failed_logins_7d: AuditLog.where(action: 'user.failed_login').where('created_at > ?', 7.days.ago).count,
          document_deletions_30d: AuditLog.where(action: 'document.delete').where('created_at > ?', 30.days.ago).count,
          total_audit_events: AuditLog.count
        },
        recent_activity: {
          recent_documents: recent_documents(5),
          recent_queries: recent_queries(5),
          recent_users: recent_users(5)
        }
      }

      render json: {
        status: { code: 200, message: 'Analytics dashboard retrieved successfully' },
        data: analytics_data
      }
    end

    private

    def active_users_count(since)
      AuditLog.where('created_at > ?', since).distinct.count(:user_id)
    end

    def top_document_uploaders(limit)
      Document.group(:user_id)
              .select('user_id, COUNT(*) as document_count')
              .order('document_count DESC')
              .limit(limit)
              .map do |doc|
        user = User.find_by(id: doc.user_id)
        {
          user_id: doc.user_id,
          email: user&.email,
          full_name: user&.full_name,
          document_count: doc.document_count
        }
      end
    end

    def top_queriers(limit)
      Query.group(:user_id)
           .select('user_id, COUNT(*) as query_count')
           .order('query_count DESC')
           .limit(limit)
           .map do |query|
        user = User.find_by(id: query.user_id)
        {
          user_id: query.user_id,
          email: user&.email,
          full_name: user&.full_name,
          query_count: query.query_count
        }
      end
    end

    def recent_documents(limit)
      Document.order(created_at: :desc).limit(limit).map do |doc|
        {
          id: doc.id,
          title: doc.title,
          filename: doc.filename,
          status: doc.status,
          created_at: doc.created_at,
          user: {
            id: doc.user.id,
            email: doc.user.email,
            full_name: doc.user.full_name
          }
        }
      end
    end

    def recent_queries(limit)
      Query.order(created_at: :desc).limit(limit).map do |query|
        {
          id: query.id,
          question: query.question.truncate(100),
          status: query.status,
          created_at: query.created_at,
          user: {
            id: query.user.id,
            email: query.user.email,
            full_name: query.user.full_name
          }
        }
      end
    end

    def recent_users(limit)
      User.order(created_at: :desc).limit(limit).map do |user|
        {
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          role: user.role,
          created_at: user.created_at
        }
      end
    end
  end
end
