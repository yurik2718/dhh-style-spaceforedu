require "test_helper"

class Admin::HomologationRequests::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "creates a conversation when one does not exist and redirects to it" do
    request_record = homologation_requests(:awaiting_payment)
    assert_nil request_record.conversation

    sign_in_as @admin
    assert_difference("Conversation.count", 1) do
      post admin_homologation_request_conversation_path(request_record)
    end

    request_record.reload
    assert_redirected_to conversation_path(request_record.conversation)
  end

  test "redirects to existing conversation when one already exists" do
    request_record = homologation_requests(:in_pipeline_es)
    existing       = request_record.conversation
    assert_not_nil existing

    sign_in_as @admin
    assert_no_difference("Conversation.count") do
      post admin_homologation_request_conversation_path(request_record)
    end

    assert_redirected_to conversation_path(existing)
  end

  test "staff can start a conversation" do
    request_record = homologation_requests(:awaiting_payment)
    sign_in_as users(:staff_es)

    assert_difference("Conversation.count", 1) do
      post admin_homologation_request_conversation_path(request_record)
    end
  end

  test "students cannot start a conversation through admin endpoint" do
    sign_in_as users(:student_es)
    post admin_homologation_request_conversation_path(homologation_requests(:awaiting_payment))
    assert_redirected_to root_path
  end

  test "unauthenticated visitors are redirected to sign in" do
    post admin_homologation_request_conversation_path(homologation_requests(:awaiting_payment))
    assert_redirected_to new_session_path
  end
end
