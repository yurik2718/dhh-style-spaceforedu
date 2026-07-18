require "test_helper"

class Admin::HomologationRequests::StatusTransitionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @homologation_request = homologation_requests(:awaiting_payment)
    @admin   = users(:admin)
  end

  test "super_admin transitions status and is redirected" do
    sign_in_as @admin
    post admin_homologation_request_status_transitions_path(@homologation_request),
         params: { status_transition: { status: "in_review" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert_equal I18n.t("flash.status_changed"), flash[:notice]
    assert_equal "in_review", @homologation_request.reload.status
  end

  test "staff transitions status and is redirected" do
    sign_in_as users(:staff_es)
    post admin_homologation_request_status_transitions_path(@homologation_request),
         params: { status_transition: { status: "in_review" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert_equal "in_review", @homologation_request.reload.status
  end

  test "invalid status redirects with an alert" do
    sign_in_as @admin
    post admin_homologation_request_status_transitions_path(@homologation_request),
         params: { status_transition: { status: "bogus" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert_not_nil flash[:alert]
    assert_equal "awaiting_payment", @homologation_request.reload.status
  end

  test "students are redirected to root with not-authorized alert" do
    sign_in_as users(:student_es)
    post admin_homologation_request_status_transitions_path(@homologation_request),
         params: { status_transition: { status: "in_review" } }

    assert_redirected_to root_path
    assert_equal "awaiting_payment", @homologation_request.reload.status
  end

  test "unauthenticated visitors are redirected to sign in" do
    post admin_homologation_request_status_transitions_path(@homologation_request),
         params: { status_transition: { status: "in_review" } }
    assert_redirected_to new_session_path
  end

  test "declined without a reason is rejected with an alert" do
    sign_in_as @admin
    post admin_homologation_request_status_transitions_path(@homologation_request),
         params: { status_transition: { status: "declined", reason: "  " } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert_equal I18n.t("admin.requests.errors.decline_reason_required"), flash[:alert]
    assert_equal "awaiting_payment", @homologation_request.reload.status
  end

  test "declined with a reason posts the reason as a chat message and flips status" do
    sign_in_as @admin
    @homologation_request.update_columns(status: "in_review", status_changed_by: @admin.id, status_changed_at: 1.hour.ago)

    assert_difference -> { Message.count }, 1 do
      post admin_homologation_request_status_transitions_path(@homologation_request),
           params: { status_transition: { status: "declined", reason: "Documento no elegible." } }
    end

    assert_equal "declined", @homologation_request.reload.status
    assert_equal "Documento no elegible.", @homologation_request.conversation.messages.last.body
  end
end
