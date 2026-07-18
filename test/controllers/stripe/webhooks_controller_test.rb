require "test_helper"

module Stripe
  class WebhooksControllerTest < ActionDispatch::IntegrationTest
    def post_signed_event(payload)
      timestamp = Time.now.to_i
      secret    = Rails.application.credentials.dig(:stripe, :webhook_secret)
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")

      post "/stripe/webhooks",
           params: payload,
           headers: {
             "CONTENT_TYPE"     => "application/json",
             "Stripe-Signature" => "t=#{timestamp},v1=#{signature}"
           }
    end

    def event_payload(id:, type:, request_id: nil, intent_id: "pi_test_1")
      {
        id:   id,
        type: type,
        data: { object: { id: intent_id, metadata: { homologation_request_id: request_id } } }
      }.to_json
    end

    test "POST without a Stripe-Signature header returns 400" do
      post "/stripe/webhooks",
           params: '{"id":"evt_test","type":"payment_intent.succeeded"}',
           headers: { "CONTENT_TYPE" => "application/json" }

      assert_response :bad_request
    end

    test "POST with an invalid Stripe-Signature returns 400" do
      post "/stripe/webhooks",
           params: '{"id":"evt_test","type":"payment_intent.succeeded"}',
           headers: {
             "CONTENT_TYPE"     => "application/json",
             "Stripe-Signature" => "t=123,v1=not_a_real_signature"
           }

      assert_response :bad_request
    end

    test "POST with a valid signature returns 200 for an event we do not specifically handle" do
      post_signed_event '{"id":"evt_unhandled","type":"customer.created","data":{"object":{}}}'

      assert_response :ok
    end

    test "payment_intent.succeeded confirms payment on the matching request" do
      request = homologation_requests(:awaiting_payment)
      post_signed_event event_payload(id: "evt_pi_succeeded_1", type: "payment_intent.succeeded", request_id: request.id)

      assert_response :ok
      assert_equal "payment_confirmed", request.reload.status
      assert_not_nil request.payment_confirmed_at
    end

    test "payment_intent.succeeded notifies the super admin that the payment arrived" do
      request = homologation_requests(:awaiting_payment)
      admin   = users(:admin)

      assert_difference -> {
        admin.notifications.where(notifiable: request, title_key: "notifications.payment_received.title").count
      }, 1 do
        post_signed_event event_payload(id: "evt_pi_succeeded_admin_notif", type: "payment_intent.succeeded", request_id: request.id)
      end
    end

    test "payment_intent.payment_failed notifies the super admin" do
      request = homologation_requests(:awaiting_payment)
      admin   = users(:admin)

      assert_difference -> { admin.notifications.where(notifiable: request).count }, 1 do
        post_signed_event event_payload(id: "evt_pi_failed_1", type: "payment_intent.payment_failed", request_id: request.id)
      end

      assert_response :ok
      assert_equal "awaiting_payment", request.reload.status
    end

    test "payment_intent.succeeded for an unknown request id returns 200 without crashing" do
      post_signed_event event_payload(id: "evt_pi_unknown", type: "payment_intent.succeeded", request_id: 999_999)

      assert_response :ok
    end

    test "payment_intent.succeeded with no metadata returns 200 without crashing" do
      payload = {
        id:   "evt_pi_no_metadata",
        type: "payment_intent.succeeded",
        data: { object: { id: "pi_no_meta" } }
      }.to_json

      post_signed_event payload

      assert_response :ok
    end

    test "redelivered event with the same id is a no-op" do
      request = homologation_requests(:awaiting_payment)
      payload = event_payload(id: "evt_pi_succeeded_dup", type: "payment_intent.succeeded", request_id: request.id)

      post_signed_event payload
      assert_response :ok
      first_confirmed_at = request.reload.payment_confirmed_at

      travel 5.minutes do
        post_signed_event payload
      end

      assert_response :ok
      assert_equal first_confirmed_at, request.reload.payment_confirmed_at,
                   "duplicate event must not overwrite payment_confirmed_at"
    end

    test "payment_intent.payment_failed also tells the student so they can retry" do
      request = homologation_requests(:awaiting_payment)
      student = request.user

      assert_difference -> { student.notifications.where(notifiable: request).count }, 1 do
        post_signed_event event_payload(id: "evt_pi_failed_student", type: "payment_intent.payment_failed", request_id: request.id)
      end

      assert_response :ok
    end

    test "payment_intent.succeeded without a super admin returns 500 and forgets the event so Stripe retries it" do
      User.where(role: "super_admin").update_all(role: "student")
      request = homologation_requests(:awaiting_payment)

      post_signed_event event_payload(id: "evt_no_admin", type: "payment_intent.succeeded", request_id: request.id)

      assert_response :internal_server_error
      assert_not StripeEvent.exists?("evt_no_admin"), "event must be forgotten so the Stripe retry is processed fresh"
      assert_equal "awaiting_payment", request.reload.status
    end

    test "delayed succeeded webhook is idempotent and does not reset pipeline_stage" do
      request = homologation_requests(:awaiting_payment)
      admin   = users(:admin)
      request.confirm_payment!(confirmed_by: admin)
      request.advance_pipeline!(changed_by: admin)
      stage_before = request.reload.pipeline_stage
      assert_not_equal PipelineFlow::STARTING_STAGE, stage_before

      post_signed_event event_payload(id: "evt_pi_succeeded_late", type: "payment_intent.succeeded", request_id: request.id)

      assert_response :ok
      assert_equal stage_before, request.reload.pipeline_stage
    end
  end
end
