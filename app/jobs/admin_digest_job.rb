# Weekly nudge for the owner: pipeline cases that haven't moved and inbox
# items nobody answered. Sends nothing when the desk is clean.
class AdminDigestJob < ApplicationJob
  queue_as :default

  PIPELINE_STALE_AFTER = 7.days
  INBOX_STALE_AFTER    = 2.days

  def perform
    admin = User.super_admin
    return unless admin

    stale = HomologationRequest.kept.includes(:user)
      .where(status: %w[payment_confirmed in_progress])
      .where(pipeline_changed_at: ...PIPELINE_STALE_AFTER.ago)
      .order(:pipeline_changed_at)
      .to_a

    inbox = HomologationRequest.kept.includes(:user)
      .where(status: %w[submitted in_review])
      .where(status_changed_at: ...INBOX_STALE_AFTER.ago)
      .order(:status_changed_at)
      .to_a

    return if stale.empty? && inbox.empty?

    AdminDigestMailer.weekly(admin: admin, stale: stale, inbox: inbox).deliver_later
  end
end
