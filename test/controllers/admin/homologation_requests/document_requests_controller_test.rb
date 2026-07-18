require "test_helper"

class Admin::HomologationRequests::DocumentRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @hr    = homologation_requests(:in_pipeline_es)
    @hr.update_columns(status: "in_review", status_changed_by: @admin.id, status_changed_at: 1.hour.ago)
  end

  test "POST create flips status to awaiting_reply and posts the reason to chat" do
    sign_in_as @admin

    assert_difference -> { @hr.conversation.messages.count }, 1 do
      post admin_homologation_request_document_request_path(@hr),
           params: { document_request: { reason: "Please send a clearer scan of the diploma." } }
    end

    assert_redirected_to admin_homologation_request_path(@hr)
    assert_equal "awaiting_reply", @hr.reload.status
    assert_equal "Please send a clearer scan of the diploma.",
                 @hr.conversation.messages.order(:created_at).last.body
  end

  test "POST create by staff flips status to awaiting_reply" do
    sign_in_as users(:staff_es)

    post admin_homologation_request_document_request_path(@hr),
         params: { document_request: { reason: "Please send a clearer scan." } }

    assert_redirected_to admin_homologation_request_path(@hr)
    assert_equal "awaiting_reply", @hr.reload.status
  end

  test "POST create without a reason redirects with an alert and leaves status unchanged" do
    sign_in_as @admin

    assert_no_difference -> { Message.count } do
      post admin_homologation_request_document_request_path(@hr),
           params: { document_request: { reason: "   " } }
    end

    assert_redirected_to admin_homologation_request_path(@hr)
    assert_not_nil flash[:alert]
    assert_equal "in_review", @hr.reload.status
  end

  test "POST create by a student is rejected" do
    sign_in_as users(:student_es)

    post admin_homologation_request_document_request_path(@hr),
         params: { document_request: { reason: "test" } }

    assert_redirected_to root_path
    assert_equal "in_review", @hr.reload.status
  end

  test "POST create unauthenticated redirects to sign in" do
    post admin_homologation_request_document_request_path(@hr),
         params: { document_request: { reason: "test" } }

    assert_redirected_to new_session_path
    assert_equal "in_review", @hr.reload.status
  end
end
