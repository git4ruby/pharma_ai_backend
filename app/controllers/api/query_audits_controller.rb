class Api::QueryAuditsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_auditor!

  def index
    @queries = Query.all.recent.includes(:user, :citations, :documents)

    # Apply filters
    @queries = @queries.where(user_id: params[:user_id]) if params[:user_id].present?
    @queries = @queries.where(status: params[:status]) if params[:status].present?

    # Date range filtering
    if params[:start_date].present?
      @queries = @queries.where('created_at >= ?', params[:start_date])
    end
    if params[:end_date].present?
      @queries = @queries.where('created_at <= ?', params[:end_date])
    end

    # Search in questions
    if params[:search].present?
      @queries = @queries.where('question ILIKE ?', "%#{params[:search]}%")
    end

    # Pagination
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    @queries = @queries.offset((page - 1) * per_page).limit(per_page)

    total_count = Query.all.count

    render json: {
      status: { code: 200, message: 'Query audit data retrieved successfully' },
      data: @queries.map { |query| audit_query_json(query) },
      meta: {
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def statistics
    stats = {
      total_queries: Query.count,
      queries_by_status: Query.group(:status).count,
      queries_by_user: Query.joins(:user).group('users.email').count,
      queries_by_role: Query.joins(:user).group('users.role').count,
      recent_activity: Query.where('created_at >= ?', 7.days.ago).count,
      average_processing_time: Query.where(status: 'completed').average(:processing_time)&.round(2),
      queries_today: Query.where('created_at >= ?', Date.today).count,
      queries_this_week: Query.where('created_at >= ?', 1.week.ago).count,
      queries_this_month: Query.where('created_at >= ?', 1.month.ago).count
    }

    render json: {
      status: { code: 200, message: 'Statistics retrieved successfully' },
      data: stats
    }
  end

  private

  def authorize_auditor!
    unless current_user.admin? || current_user.auditor?
      render json: {
        status: { code: 403, message: 'Access denied. Admin or Auditor role required.' }
      }, status: :forbidden
    end
  end

  def audit_query_json(query)
    {
      id: query.id,
      question: query.question,
      answer: query.answer,
      status: query.status,
      processing_time: query.processing_time,
      queried_at: query.queried_at,
      created_at: query.created_at,
      user: {
        id: query.user.id,
        email: query.user.email,
        full_name: query.user.full_name,
        role: query.user.role
      },
      documents_accessed: query.documents.map do |doc|
        {
          id: doc.id,
          title: doc.title,
          filename: doc.filename,
          classification: doc.classification
        }
      end,
      citation_count: query.citations.count
    }
  end
end
