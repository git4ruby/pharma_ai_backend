class Api::Admin::S3Controller < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin

  # POST /api/admin/s3/import
  def import
    Rails.logger.info "Manual S3 import triggered by admin user: #{current_user.email}"

    # Enqueue the job immediately
    S3ImportJob.perform_later

    render json: {
      status: { code: 200, message: 'S3 import job has been queued successfully' },
      data: {
        message: 'Checking S3 bucket for new documents. Processing will begin shortly.',
        initiated_by: current_user.email,
        initiated_at: Time.current
      }
    }
  rescue => e
    Rails.logger.error "Failed to queue S3 import job: #{e.message}"
    render json: {
      status: { code: 500, message: 'Failed to queue S3 import job' },
      errors: [e.message]
    }, status: :internal_server_error
  end

  private

  def authorize_admin
    unless current_user.admin?
      render json: {
        status: { code: 403, message: 'You are not authorized to perform this action' }
      }, status: :forbidden
    end
  end
end
