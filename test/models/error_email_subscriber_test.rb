require "test_helper"

class ErrorEmailSubscriberTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @subscriber = ErrorEmailSubscriber.new(cache: ActiveSupport::Cache::MemoryStore.new)
  end

  def boom
    raise "kaboom"
  rescue => e
    e
  end

  test "emails the owner about an error" do
    error = boom

    assert_enqueued_emails 1 do
      @subscriber.report(error, handled: false, severity: :error, context: { job: "NotificationJob" })
    end
  end

  test "the same error within the dedup window is emailed only once" do
    error = boom

    assert_enqueued_emails 1 do
      3.times { @subscriber.report(error, handled: false, severity: :error) }
    end
  end

  test "a subscriber failure never raises into the caller" do
    always_failing_cache = Object.new.tap do |cache|
      def cache.write(*, **) = raise("cache down")
    end

    assert_nothing_raised do
      ErrorEmailSubscriber.new(cache: always_failing_cache)
        .report(boom, handled: false, severity: :error)
    end
  end

  test "report mail contains class, message and backtrace" do
    error = boom

    perform_enqueued_jobs do
      @subscriber.report(error, handled: false, severity: :error)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_match "RuntimeError", mail.subject
    assert_match "kaboom",       mail.body.to_s
    assert_match "error_email_subscriber_test", mail.body.to_s
  end
end
