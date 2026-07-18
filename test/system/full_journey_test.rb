require "application_system_test_case"

# The money path, end to end through the browser: a submitted case is approved,
# discussed in chat, paid (webhook effect simulated at the model boundary —
# the Stripe webhook itself is integration-tested), and starts moving through
# the pipeline. Both locales in play are Spanish (fixture default).
class FullJourneyTest < ApplicationSystemTestCase
  setup do
    @student = users(:student_es)
    @admin   = users(:admin)
    @request = @student.homologation_requests.create!(
      subject: "Grado en Biología", plan_key: "completo",
      status: "draft", privacy_accepted: true
    )
    %w[diploma transcript passport].each { |kind| attach_request_document(@request, kind: kind) }
    @request.transition_to!("submitted", changed_by: @student)
  end

  def es(key, **args) = I18n.t(key, locale: :es, **args)

  # sign_in_as returns as soon as the form is clicked; navigating away before
  # the login redirect lands gets that navigation aborted. Settle first.
  def sign_in_settled(user)
    sign_in_as user
    assert_no_selector "input[name='password']", wait: 10
  end

  def wait_until(timeout: 10)
    deadline = Time.current + timeout
    sleep 0.1 until yield || Time.current > deadline
    assert yield, "condition was not met within #{timeout}s"
  end

  test "submission → approval → chat → payment → pipeline movement" do
    # Admin triages the submission and approves it for payment
    sign_in_settled @admin
    visit admin_homologation_request_path(@request)
    click_on es("admin.requests.actions.approve_for_payment")

    assert_text es("requests.status.awaiting_payment"), wait: 10
    assert_equal "awaiting_payment", @request.reload.status

    # Admin tells the student in chat (own bubble arrives via Action Cable,
    # which the test adapter drops — verify persistence at the model)
    visit conversation_path(@request.conversation)
    fill_in "message[body]", with: "Caso aprobado. Ya puedes realizar el pago."
    click_on es("actions.send")
    wait_until { @request.conversation.messages.exists?(user: @admin) }

    # Student sees the payment button (checkout redirect to Stripe stops here)
    Capybara.reset_sessions!
    sign_in_settled @student
    visit homologation_request_path(@request)
    assert_text es("requests.payment.pay_now", amount: "").strip.split.first, wait: 10

    # Stripe confirms — same call the webhook makes
    @request.reload.confirm_payment!(confirmed_by: @admin)

    # Student reads the admin's message and thanks in chat
    visit conversation_path(@request.conversation)
    assert_text "Caso aprobado"
    fill_in "message[body]", with: "¡Gracias! Pago realizado."
    click_on es("actions.send")
    wait_until { @request.conversation.messages.exists?(user: @student) }

    visit conversation_path(@request.conversation)
    assert_text "Pago realizado"

    # Admin sees the paid case at the pipeline start and advances it
    Capybara.reset_sessions!
    sign_in_settled @admin
    visit admin_homologation_request_path(@request)
    assert_equal "pago_recibido", @request.reload.pipeline_stage

    click_on es("admin.requests.actions.advance")

    assert_text es("flash.pipeline_advanced"), wait: 10
    assert_not_equal "pago_recibido", @request.reload.pipeline_stage
  end
end
