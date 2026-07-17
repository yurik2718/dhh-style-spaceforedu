require "test_helper"

class RequestRetentionJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:student_es)
  end

  def build_request(status:, changed_at:)
    @user.homologation_requests.create!(
      subject: "Expired case", plan_key: "basico", privacy_accepted: true,
      status: status, status_changed_at: changed_at
    )
  end

  test "purges terminal requests older than five years with their chat and documents" do
    request = build_request(status: "closed", changed_at: 6.years.ago)
    attach_request_document(request, kind: "passport")
    conversation = request.conversation
    conversation.messages.create!(user: @user, body: "old talk")

    RequestRetentionJob.perform_now

    assert_not HomologationRequest.exists?(request.id)
    assert_not Conversation.exists?(conversation.id)
    assert_equal 0, conversation.messages.count
    assert_equal 0, RequestDocument.where(homologation_request_id: request.id).count
  end

  test "keeps terminal requests younger than five years" do
    request = build_request(status: "resolved", changed_at: 4.years.ago)

    RequestRetentionJob.perform_now

    assert HomologationRequest.exists?(request.id)
  end

  test "never touches non-terminal requests, however old" do
    request = build_request(status: "in_progress", changed_at: 6.years.ago)

    RequestRetentionJob.perform_now

    assert HomologationRequest.exists?(request.id)
  end
end
