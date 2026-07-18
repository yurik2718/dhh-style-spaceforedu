require "test_helper"
require "webmock/minitest"

class UserAnonymizationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:student_es)
  end

  test "anonymize! purges documents, avatar and enqueued via request_documents" do
    doc = attach_request_document(homologation_requests(:in_pipeline_es), kind: "passport")

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      @user.anonymize!
    end

    assert doc.file.attached?, "blob purge is async — attachment row still present until job runs"
  end

  test "anonymize! scrubs PII columns and discards the account" do
    @user.update!(passport: "AB1234567", phone: "+34 600 000 000", birthday: Date.new(1990, 1, 1))

    @user.anonymize!
    @user.reload

    assert_equal "deleted_#{@user.id}@anonymized.local", @user.email_address
    assert_nil @user.passport
    assert_nil @user.phone
    assert_nil @user.birthday
    assert_nil @user.country
    assert_not_nil @user.discarded_at
  end

  test "anonymize! scrubs chat message bodies and removes sessions, notifications, push subscriptions" do
    message = messages(:student_reply)
    @user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    @user.notifications.create!(title: "t", body: "b", notifiable: homologation_requests(:in_pipeline_es))
    @user.push_subscriptions.create!(endpoint: "https://push.example.com/1", p256dh_key: "k", auth_key: "a")

    @user.anonymize!

    assert_equal "[eliminado]", message.reload.body
    assert_empty @user.sessions.reload
    assert_empty @user.notifications.reload
    assert_empty @user.push_subscriptions.reload
  end

  test "anonymize! does not touch other users' messages" do
    admin_message = messages(:old_admin_hello)

    @user.anonymize!

    assert_equal "Welcome, please send your diploma.", admin_message.reload.body
  end

  test "anonymize! deletes the Stripe customer when one exists" do
    @user.update_column(:stripe_customer_id, "cus_test123")
    stub = stub_request(:delete, "https://api.stripe.com/v1/customers/cus_test123")
      .to_return(status: 200, body: { id: "cus_test123", deleted: true }.to_json)

    with_stripe_api_key do
      @user.anonymize!
    end

    assert_requested stub
    assert_nil @user.reload.stripe_customer_id
  end

  test "anonymize! survives a Stripe API error and still scrubs the account" do
    @user.update_column(:stripe_customer_id, "cus_gone")
    stub_request(:delete, "https://api.stripe.com/v1/customers/cus_gone")
      .to_return(status: 404, body: { error: { type: "invalid_request_error" } }.to_json)

    with_stripe_api_key do
      @user.anonymize!
    end

    assert_not_nil @user.reload.discarded_at
  end

  test "UserAnonymizationJob only anonymizes when deletion was requested" do
    UserAnonymizationJob.perform_now(@user.id)
    assert_nil @user.reload.discarded_at

    @user.request_deletion!
    perform_enqueued_jobs only: UserAnonymizationJob
    assert_not_nil @user.reload.discarded_at
  end

  private
    def with_stripe_api_key
      Stripe.api_key = "sk_test_fake"
      yield
    ensure
      Stripe.api_key = nil
    end
end
