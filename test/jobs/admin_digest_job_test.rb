require "test_helper"

class AdminDigestJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    # A quiet baseline: nothing stale, nothing in the inbox.
    HomologationRequest.update_all(status: "closed", pipeline_changed_at: 1.day.ago)
  end

  test "emails every case_staff member a digest of stale pipeline cases and unanswered inbox" do
    stale = homologation_requests(:in_pipeline_es)
    stale.update_columns(status: "in_progress", pipeline_changed_at: 10.days.ago)

    inbox = homologation_requests(:awaiting_payment)
    inbox.update_columns(status: "submitted", status_changed_at: 3.days.ago, payment_confirmed_at: nil)

    # One email per case_staff member (fixtures: admin + staff_es), not just the super admin.
    assert_enqueued_emails 2 do
      AdminDigestJob.perform_now
    end
  end

  test "sends nothing when there is nothing to report" do
    assert_enqueued_emails 0 do
      AdminDigestJob.perform_now
    end
  end

  test "fresh work is not nagged about" do
    fresh = homologation_requests(:in_pipeline_es)
    fresh.update_columns(status: "in_progress", pipeline_changed_at: 2.days.ago)

    assert_enqueued_emails 0 do
      AdminDigestJob.perform_now
    end
  end

  test "digest lists the stale case with its stage" do
    stale = homologation_requests(:in_pipeline_es)
    stale.update_columns(status: "in_progress", pipeline_changed_at: 10.days.ago)

    mail = AdminDigestMailer.weekly(
      admin: users(:admin),
      stale: [ stale ],
      inbox: []
    )

    assert_match stale.subject,        mail.body.to_s
    assert_match stale.pipeline_stage, mail.body.to_s
  end
end
