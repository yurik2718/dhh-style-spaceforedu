require "test_helper"

class Admin::HomologationRequests::PipelineRetreatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @homologation_request = homologation_requests(:in_pipeline_es)
  end

  test "super_admin retreats the pipeline with a reason and gets a notice" do
    sign_in_as users(:admin)

    post admin_homologation_request_pipeline_retreat_path(@homologation_request),
         params: { pipeline_retreat: { reason: "Wrong stage by mistake" } }

    assert_redirected_to admin_pipeline_path
    assert_equal I18n.t("flash.pipeline_retreated"), flash[:notice]

    @homologation_request.reload
    assert_equal "pago_recibido", @homologation_request.pipeline_stage
    assert_includes @homologation_request.pipeline_notes, "Wrong stage by mistake"
  end

  test "blank reason redirects with an alert and leaves the stage untouched" do
    sign_in_as users(:admin)

    post admin_homologation_request_pipeline_retreat_path(@homologation_request),
         params: { pipeline_retreat: { reason: "   " } }

    assert_redirected_to admin_pipeline_path
    assert_not_nil flash[:alert]
    assert_equal "documentos", @homologation_request.reload.pipeline_stage
  end

  test "missing pipeline_retreat params redirect with an alert" do
    sign_in_as users(:admin)

    post admin_homologation_request_pipeline_retreat_path(@homologation_request)

    assert_redirected_to admin_pipeline_path
    assert_not_nil flash[:alert]
    assert_equal "documentos", @homologation_request.reload.pipeline_stage
  end

  test "staff cannot retreat the pipeline" do
    sign_in_as users(:staff_es)

    post admin_homologation_request_pipeline_retreat_path(@homologation_request),
         params: { pipeline_retreat: { reason: "anything" } }

    assert_redirected_to root_path
    assert_equal "documentos", @homologation_request.reload.pipeline_stage
  end

  test "students are redirected to root with not-authorized alert" do
    sign_in_as users(:student_es)

    post admin_homologation_request_pipeline_retreat_path(@homologation_request),
         params: { pipeline_retreat: { reason: "anything" } }

    assert_redirected_to root_path
    assert_equal I18n.t("errors.not_authorized"), flash[:alert]
    assert_equal "documentos", @homologation_request.reload.pipeline_stage
  end

  test "unauthenticated visitors are redirected to sign in" do
    post admin_homologation_request_pipeline_retreat_path(@homologation_request),
         params: { pipeline_retreat: { reason: "anything" } }

    assert_redirected_to new_session_path
  end

  test "retreating from pago_recibido (no previous stage) redirects with an alert" do
    sign_in_as users(:admin)
    request_record = homologation_requests(:at_pago_recibido)

    post admin_homologation_request_pipeline_retreat_path(request_record),
         params: { pipeline_retreat: { reason: "rollback" } }

    assert_redirected_to admin_pipeline_path
    assert_not_nil flash[:alert]
    assert_equal "pago_recibido", request_record.reload.pipeline_stage
  end
end
