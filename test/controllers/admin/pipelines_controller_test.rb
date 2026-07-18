require "test_helper"

class Admin::PipelinesControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated visitors to the sign-in page" do
    get admin_pipeline_path

    assert_redirected_to new_session_path
  end

  test "redirects students to root with the not-authorized alert" do
    sign_in_as users(:student_es)

    get admin_pipeline_path

    assert_redirected_to root_path
    assert_equal I18n.t("errors.not_authorized"), flash[:alert]
  end

  test "super_admin reaches show and renders kanban + horizontal stage headers" do
    sign_in_as users(:admin)

    get admin_pipeline_path

    assert_response :success
    assert_select "section[data-stage=documentos] h3", text: I18n.t("pipeline.stages.documentos")
    assert_select "section[data-stage=completado] h3", text: I18n.t("pipeline.stages.completado")
  end

  test "super_admin show lists active in_pipeline requests in their kanban column" do
    sign_in_as users(:admin)
    request_record = homologation_requests(:in_pipeline_es)

    get admin_pipeline_path

    assert_select "section[data-stage=documentos] ##{ActionView::RecordIdentifier.dom_id(request_record)}"
  end

  test "staff reaches show but does not see the invite-staff link" do
    sign_in_as users(:staff_es)

    get admin_pipeline_path

    assert_response :success
    assert_select "a[href=?]", new_admin_staff_member_path, count: 0
  end

  test "super_admin sees the invite-staff link" do
    sign_in_as users(:admin)

    get admin_pipeline_path

    assert_select "a[href=?]", new_admin_staff_member_path
  end

  test "revenue stat is always rendered in euros, never dollars" do
    sign_in_as users(:admin)

    get admin_pipeline_path

    assert_match(/\d[\d.,\s]*\s*€/, response.body, "revenue must be formatted with the € symbol")
    assert_no_match(/\$\d/, response.body, "revenue must never use the $ symbol")
  end
end
