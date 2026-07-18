require "test_helper"

class Admin::HomologationRequests::PaymentConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @homologation_request = homologation_requests(:awaiting_payment)
    @admin   = users(:admin)
  end

  test "super_admin confirms payment, transitioning status and seeding pipeline" do
    sign_in_as @admin
    post admin_homologation_request_payment_confirmation_path(@homologation_request)

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert_equal I18n.t("flash.payment_confirmed"), flash[:notice]

    @homologation_request.reload
    assert_equal "payment_confirmed", @homologation_request.status
    assert_equal "pago_recibido",     @homologation_request.pipeline_stage
    assert_equal @admin.id,           @homologation_request.payment_confirmed_by
  end

  test "staff cannot confirm payment" do
    sign_in_as users(:staff_es)
    post admin_homologation_request_payment_confirmation_path(@homologation_request)

    assert_redirected_to root_path
    assert_equal "awaiting_payment", @homologation_request.reload.status
  end

  test "students cannot confirm payment" do
    sign_in_as users(:student_es)
    post admin_homologation_request_payment_confirmation_path(@homologation_request)

    assert_redirected_to root_path
    assert_equal "awaiting_payment", @homologation_request.reload.status
  end

  test "unauthenticated visitors are redirected to sign in" do
    post admin_homologation_request_payment_confirmation_path(@homologation_request)
    assert_redirected_to new_session_path
  end
end
