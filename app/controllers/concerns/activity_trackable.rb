# ActivityTrackable Concern
# Automatically tracks user activity for session timeout management
#
# How it works:
# 1. On every API request, updates last_activity timestamp in Redis
# 2. Extends session timeout by 15 minutes
# 3. Updates last_activity_at in database
#
# Usage:
#   include ActivityTrackable
#   before_action :track_activity

module ActivityTrackable
  extend ActiveSupport::Concern

  included do
    before_action :track_activity, if: :user_signed_in?
  end

  private

  def track_activity
    return unless current_user

    # Update last activity in Redis (extends session timeout)
    SessionTracker.update_activity(current_user.id)

    # Update database timestamp every 5 minutes to reduce DB writes
    if should_update_database?
      current_user.update_column(:last_activity_at, Time.current)
    end
  end

  # Only update database every 5 minutes to reduce writes
  def should_update_database?
    return true unless current_user.last_activity_at

    current_user.last_activity_at < 5.minutes.ago
  end
end
