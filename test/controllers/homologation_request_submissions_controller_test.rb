require "test_helper"

class HomologationRequestSubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student = users(:student_es)
    @other   = users(:student_other)
    @draft   = @student.homologation_requests.create!(
      subject: "draft", plan_key: "basico", status: "draft", privacy_accepted: true
    )
    RequestDocument::REQUIRED_KINDS.each { |kind| attach_request_document(@draft, kind: kind) }
  end

  test "POST create transitions a draft to submitted and redirects" do
    sign_in_as @student
    post homologation_request_submission_path(@draft)

    assert_redirected_to homologation_request_path(@draft)
    assert_equal I18n.t("flash.request_submitted"), flash[:notice]
    fresh = HomologationRequest.find(@draft.id)
    assert_equal "submitted",  fresh.status
    assert_equal @student.id,  fresh.status_changed_by
  end

  test "POST create notifies the super admin about the new submission" do
    sign_in_as @student
    admin = users(:admin)

    assert_difference -> { admin.notifications.where(notifiable: @draft).count }, 1 do
      post homologation_request_submission_path(@draft)
    end

    notification = admin.notifications.where(notifiable: @draft).last
    assert_equal "notifications.request_submitted.title", notification.title_key
  end

  test "POST create notifies staff too, not just the super admin" do
    sign_in_as @student
    staff = users(:staff_es)

    assert_difference -> { staff.notifications.where(notifiable: @draft).count }, 1 do
      post homologation_request_submission_path(@draft)
    end
  end

  test "POST create on a non-draft status redirects with an alert" do
    sign_in_as @student
    submitted = @student.homologation_requests.create!(
      subject: "x", plan_key: "basico", status: "submitted", privacy_accepted: true
    )

    post homologation_request_submission_path(submitted)

    assert_redirected_to homologation_request_path(submitted)
    assert_not_nil flash[:alert]
    assert_equal "submitted", submitted.reload.status
  end

  test "POST create by another student is rejected" do
    sign_in_as @other
    post homologation_request_submission_path(@draft)
    assert_redirected_to root_path
    assert_equal "draft", HomologationRequest.find(@draft.id).status
  end

  test "POST create unauthenticated redirects to sign in" do
    post homologation_request_submission_path(@draft)
    assert_redirected_to new_session_path
  end

  test "POST create on a draft missing attachments shows the alert and stays in draft" do
    sign_in_as @student
    empty_draft = @student.homologation_requests.create!(
      subject: "empty", plan_key: "basico", status: "draft", privacy_accepted: true
    )

    post homologation_request_submission_path(empty_draft)

    assert_redirected_to homologation_request_path(empty_draft)
    assert_equal I18n.t("flash.request_not_submittable"), flash[:alert]
    assert_equal "draft", empty_draft.reload.status
  end

  # --- reply flow (awaiting_reply → in_review) ---
  #
  # Mirror of the initial submit: when the admin has asked for more documents
  # and the student is done responding, the same "send to admin" endpoint
  # flips status into in_review. One explicit click — no per-file notification
  # spam, no orphan awaiting_reply requests that the admin forgets about.

  test "POST create on awaiting_reply flips status to in_review and notifies the admin once" do
    awaiting = @student.homologation_requests.create!(
      subject: "Reply ready", plan_key: "basico", status: "awaiting_reply", privacy_accepted: true
    )
    RequestDocument::REQUIRED_KINDS.each { |kind| attach_request_document(awaiting, kind: kind) }
    admin = users(:admin)
    sign_in_as @student

    assert_difference -> {
      admin.notifications.where(notifiable: awaiting, title_key: "notifications.documents_added.title").count
    }, 1 do
      post homologation_request_submission_path(awaiting)
    end

    assert_redirected_to homologation_request_path(awaiting)
    assert_equal I18n.t("flash.reply_sent"), flash[:notice]
    assert_equal "in_review", awaiting.reload.status
  end

  test "POST create on awaiting_reply notifies staff too, not just the super admin" do
    awaiting = @student.homologation_requests.create!(
      subject: "Reply ready", plan_key: "basico", status: "awaiting_reply", privacy_accepted: true
    )
    RequestDocument::REQUIRED_KINDS.each { |kind| attach_request_document(awaiting, kind: kind) }
    staff = users(:staff_es)
    sign_in_as @student

    assert_difference -> {
      staff.notifications.where(notifiable: awaiting, title_key: "notifications.documents_added.title").count
    }, 1 do
      post homologation_request_submission_path(awaiting)
    end
  end

  test "POST create on awaiting_reply by a different student is rejected" do
    awaiting = @student.homologation_requests.create!(
      subject: "Reply ready", plan_key: "basico", status: "awaiting_reply", privacy_accepted: true
    )
    RequestDocument::REQUIRED_KINDS.each { |kind| attach_request_document(awaiting, kind: kind) }
    sign_in_as @other

    post homologation_request_submission_path(awaiting)

    assert_redirected_to root_path
    assert_equal "awaiting_reply", awaiting.reload.status
  end
end
