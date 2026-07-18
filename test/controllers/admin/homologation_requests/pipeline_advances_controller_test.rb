require "test_helper"

class Admin::HomologationRequests::PipelineAdvancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @homologation_request = homologation_requests(:in_pipeline_es)
  end

  test "super_admin advances the pipeline and gets a notice" do
    sign_in_as users(:admin)

    post admin_homologation_request_pipeline_advance_path(@homologation_request)

    assert_redirected_to admin_pipeline_path
    assert_equal I18n.t("flash.pipeline_advanced"), flash[:notice]
    assert_equal "traduccion", @homologation_request.reload.pipeline_stage
  end

  test "students are redirected to root with not-authorized alert" do
    sign_in_as users(:student_es)

    post admin_homologation_request_pipeline_advance_path(@homologation_request)

    assert_redirected_to root_path
    assert_equal I18n.t("errors.not_authorized"), flash[:alert]
    assert_equal "documentos", @homologation_request.reload.pipeline_stage
  end

  test "unauthenticated visitors are redirected to sign in" do
    post admin_homologation_request_pipeline_advance_path(@homologation_request)

    assert_redirected_to new_session_path
  end

  test "advancing past completado redirects with an alert" do
    sign_in_as users(:admin)
    finished = homologation_requests(:at_completado)

    post admin_homologation_request_pipeline_advance_path(finished)

    assert_redirected_to admin_pipeline_path
    assert flash[:alert].present?
    assert_equal "completado", finished.reload.pipeline_stage
  end
end
