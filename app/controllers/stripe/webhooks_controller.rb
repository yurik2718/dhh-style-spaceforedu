module Stripe
  class WebhooksController < ActionController::Base
    def create
      event = ::Stripe::Webhook.construct_event(
        request.body.read,
        request.headers["Stripe-Signature"].to_s,
        Rails.application.credentials.dig(:stripe, :webhook_secret)
      )

      if record(event)
        begin
          handle(event)
        rescue => e
          # Forget the event so Stripe's retry gets processed fresh instead of
          # being dropped as a duplicate — a payment must never be lost silently.
          StripeEvent.where(id: event.id).delete_all
          Rails.error.report(e, handled: true, context: { stripe_event_id: event.id })
          return head :internal_server_error
        end
      end
      head :ok
    rescue ::Stripe::SignatureVerificationError, JSON::ParserError
      head :bad_request
    end

    private
      def record(event)
        StripeEvent.insert(
          { id: event.id, type: event.type, payload: sanitize_payload(event), received_at: Time.current },
          unique_by: :id
        ).any?
      end

      def sanitize_payload(event)
        data = JSON.parse(event.to_json)
        if (obj = data.dig("data", "object"))
          %w[billing_details shipping receipt_email customer_email].each { |k| obj.delete(k) }
        end
        data.to_json
      rescue JSON::ParserError
        event.to_json
      end

      def handle(event)
        case event.type
        when "payment_intent.succeeded"      then confirm_payment(event.data.object)
        when "payment_intent.payment_failed" then notify_payment_failed(event.data.object)
        end
      end

      def confirm_payment(intent)
        request = find_request(intent)
        return unless request
        admin = User.super_admin
        raise "no super_admin user — cannot confirm payment for request ##{request.id}" unless admin

        request.confirm_payment!(confirmed_by: admin)
        admin.notify(
          notifiable: request,
          title_key:  "notifications.payment_received.title",
          body_key:   "notifications.payment_received.body",
          subject:    request.subject,
          student:    request.user.name
        )
      end

      def notify_payment_failed(intent)
        request = find_request(intent)
        return unless request

        request.user.notify(
          notifiable: request,
          title_key:  "notifications.payment_failed_student.title",
          body_key:   "notifications.payment_failed_student.body",
          subject:    request.subject
        )

        User.super_admin&.notify(
          notifiable: request,
          title_key:  "notifications.payment_failed.title",
          body_key:   "notifications.payment_failed.body",
          subject:    request.subject
        )
      end

      def find_request(intent)
        id = intent.respond_to?(:metadata) ? intent.metadata["homologation_request_id"] : nil
        return unless id
        HomologationRequest.kept.includes(:user).find_by(id: id)
      end
  end
end
