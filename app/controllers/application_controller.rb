class ApplicationController < ActionController::API
  include ActivityTrackable
  include Auditable
end
