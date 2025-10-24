class Api::Admin::BackgroundJobsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def stats
    require 'sidekiq/api'

    stats = Sidekiq::Stats.new

    render json: {
      status: { code: 200, message: 'Background job stats retrieved successfully' },
      data: {
        processed: stats.processed,
        failed: stats.failed,
        scheduled_size: stats.scheduled_size,
        retry_size: stats.retry_size,
        dead_size: stats.dead_size,
        enqueued: stats.enqueued,
        queues: stats.queues,
        workers_size: stats.workers_size,
        default_queue_latency: stats.default_queue_latency
      }
    }
  end

  def queues
    require 'sidekiq/api'

    queues = Sidekiq::Queue.all.map do |queue|
      {
        name: queue.name,
        size: queue.size,
        latency: queue.latency.round(2)
      }
    end

    render json: {
      status: { code: 200, message: 'Queue information retrieved successfully' },
      data: queues
    }
  end

  def failed_jobs
    require 'sidekiq/api'

    failed_set = Sidekiq::RetrySet.new
    dead_set = Sidekiq::DeadSet.new

    failed = failed_set.map do |job|
      {
        jid: job.jid,
        queue: job.queue,
        class: job.klass,
        args: job.args,
        error_message: job.item['error_message'],
        error_class: job.item['error_class'],
        failed_at: Time.at(job.item['failed_at']),
        retry_count: job.item['retry_count'],
        retried_at: job.item['retried_at'] ? Time.at(job.item['retried_at']) : nil
      }
    end

    dead = dead_set.map do |job|
      {
        jid: job.jid,
        queue: job.queue,
        class: job.klass,
        args: job.args,
        error_message: job.item['error_message'],
        error_class: job.item['error_class'],
        failed_at: Time.at(job.item['failed_at']),
        retry_count: job.item['retry_count']
      }
    end

    render json: {
      status: { code: 200, message: 'Failed jobs retrieved successfully' },
      data: {
        retry_jobs: failed,
        dead_jobs: dead
      }
    }
  end

  def retry_job
    require 'sidekiq/api'

    jid = params[:jid]
    retry_set = Sidekiq::RetrySet.new

    job = retry_set.find { |j| j.jid == jid }

    if job
      job.retry
      render json: {
        status: { code: 200, message: 'Job retried successfully' }
      }
    else
      render json: {
        status: { code: 404, message: 'Job not found' }
      }, status: :not_found
    end
  end

  def delete_job
    require 'sidekiq/api'

    jid = params[:jid]
    retry_set = Sidekiq::RetrySet.new
    dead_set = Sidekiq::DeadSet.new

    job = retry_set.find { |j| j.jid == jid } || dead_set.find { |j| j.jid == jid }

    if job
      job.delete
      render json: {
        status: { code: 200, message: 'Job deleted successfully' }
      }
    else
      render json: {
        status: { code: 404, message: 'Job not found' }
      }, status: :not_found
    end
  end

  def document_processing_stats
    stats = {
      total: Document.count,
      pending: Document.where(status: 'pending').count,
      processing: Document.where(status: 'processing').count,
      completed: Document.where(status: 'completed').count,
      failed: Document.where(status: 'failed').count,
      recent_completions: Document.where(status: 'completed')
                                  .order(processed_at: :desc)
                                  .limit(10)
                                  .pluck(:id, :title, :processed_at)
                                  .map { |id, title, processed_at|
                                    { id: id, title: title, processed_at: processed_at }
                                  },
      recent_failures: Document.where(status: 'failed')
                               .order(updated_at: :desc)
                               .limit(10)
                               .pluck(:id, :title, :updated_at)
                               .map { |id, title, updated_at|
                                 { id: id, title: title, failed_at: updated_at }
                               }
    }

    render json: {
      status: { code: 200, message: 'Document processing stats retrieved successfully' },
      data: stats
    }
  end

  private

  def authorize_admin!
    unless current_user.admin?
      render json: {
        status: { code: 403, message: 'Admin access required' },
        errors: ['You do not have permission to access this resource']
      }, status: :forbidden
    end
  end
end
