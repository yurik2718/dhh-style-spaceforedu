class RequestRetentionJob < ApplicationJob
  queue_as :default

  # Matches the retention promise in the privacy policy: expedientes and their
  # documents are deleted five years after the case reaches a terminal status.
  RETENTION_PERIOD = 5.years

  def perform
    HomologationRequest
      .where(status: HomologationRequest::TERMINAL_STATUSES)
      .where(status_changed_at: ..RETENTION_PERIOD.ago)
      .find_each do |request|
        request.strict_loading!(false)
        request.destroy!
      end
  end
end
