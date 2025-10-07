class Api::QueriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_query, only: [:show]

  def index
    # All users (including admins) see only their own queries in the Q&A interface
    @queries = current_user.queries.recent.includes(:user, :citations, :documents)

    render json: {
      status: { code: 200, message: 'Queries retrieved successfully' },
      data: @queries.map { |query| query_json(query) }
    }
  end

  def show
    render json: {
      status: { code: 200, message: 'Query retrieved successfully' },
      data: query_json(@query, include_citations: true)
    }
  end

  def create
    question = params[:question]

    unless question.present?
      return render json: {
        status: { code: 422, message: 'No question provided' },
        errors: ['question parameter is required']
      }, status: :unprocessable_entity
    end

    start_time = Time.current

    @query = Query.create!(
      user: current_user,
      question: question,
      status: 'pending'
    )

    begin
      @query.mark_as_processing!

      search_results = SemanticSearch.search(question, limit: 5)

      if search_results.empty?
        return render json: {
          status: { code: 404, message: 'No relevant documents found' },
          errors: ['Please upload relevant documents first']
        }, status: :not_found
      end

      context = search_results.map { |r| r[:chunk_text] }.join("\n\n---\n\n")

      ollama = OllamaService.new
      answer = ollama.generate_answer(question, context)

      processing_time = Time.current - start_time
      @query.mark_as_completed!(answer, processing_time)

      search_results.each do |result|
        @query.add_citation(
          document: result[:document],
          embedding: result[:embedding],
          score: result[:similarity]
        )
      end

      render json: {
        status: { code: 201, message: 'Query processed successfully' },
        data: query_json(@query, include_citations: true)
      }, status: :created
    rescue OllamaService::ConnectionError => e
      @query.mark_as_failed!
      render json: {
        status: { code: 503, message: 'AI service unavailable' },
        errors: [e.message]
      }, status: :service_unavailable
    rescue => e
      @query.mark_as_failed!
      render json: {
        status: { code: 500, message: 'Query processing failed' },
        errors: [e.message]
      }, status: :internal_server_error
    end
  end

  private

  def set_query
    @query = Query.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: { code: 404, message: 'Query not found' }
    }, status: :not_found
  end

  def query_json(query, include_citations: false)
    data = {
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
        full_name: query.user.full_name
      }
    }

    if include_citations
      data[:citations] = query.citations.order(relevance_score: :desc).map do |citation|
        {
          id: citation.id,
          relevance_score: citation.relevance_score,
          document: {
            id: citation.document.id,
            title: citation.document.title,
            filename: citation.document.filename
          },
          chunk_text: citation.embedding.chunk_text,
          chunk_index: citation.embedding.chunk_index
        }
      end
    end

    data
  end
end
