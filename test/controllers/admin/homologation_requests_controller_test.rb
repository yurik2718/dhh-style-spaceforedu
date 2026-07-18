require "test_helper"

class Admin::HomologationRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @homologation_request = homologation_requests(:in_pipeline_es)
    @admin   = users(:admin)
    @student = users(:student_es)
  end

  test "GET show renders for super_admin" do
    sign_in_as @admin
    get admin_homologation_request_path(@homologation_request)
    assert_response :success
    assert_select "h1", text: /#{@homologation_request.subject}/
  end

  test "GET show renders for staff" do
    sign_in_as users(:staff_es)
    get admin_homologation_request_path(@homologation_request)
    assert_response :success
    assert_select "h1", text: /#{@homologation_request.subject}/
  end

  test "GET show shows pipeline advance/retreat controls to super_admin" do
    sign_in_as @admin
    get admin_homologation_request_path(@homologation_request)

    assert_select "form[action=?]", admin_homologation_request_pipeline_advance_path(@homologation_request)
  end

  test "GET show hides pipeline advance/retreat controls from staff" do
    sign_in_as users(:staff_es)
    get admin_homologation_request_path(@homologation_request)

    assert_select "form[action=?]", admin_homologation_request_pipeline_advance_path(@homologation_request), count: 0
  end

  test "GET show shows the confirm payment button to super_admin" do
    awaiting = homologation_requests(:awaiting_payment)
    sign_in_as @admin
    get admin_homologation_request_path(awaiting)

    assert_select "form[action=?]", admin_homologation_request_payment_confirmation_path(awaiting)
  end

  test "GET show hides the confirm payment button from staff" do
    awaiting = homologation_requests(:awaiting_payment)
    sign_in_as users(:staff_es)
    get admin_homologation_request_path(awaiting)

    assert_select "form[action=?]", admin_homologation_request_payment_confirmation_path(awaiting), count: 0
  end

  test "GET show redirects students to root" do
    sign_in_as @student
    get admin_homologation_request_path(@homologation_request)
    assert_redirected_to root_path
    assert_equal I18n.t("errors.not_authorized"), flash[:alert]
  end

  test "GET show redirects unauthenticated visitors to sign in" do
    get admin_homologation_request_path(@homologation_request)
    assert_redirected_to new_session_path
  end
end
