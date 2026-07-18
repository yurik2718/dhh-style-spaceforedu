require "test_helper"

class Admin::HomologationRequests::DocumentChecklistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @homologation_request = homologation_requests(:in_pipeline_es)
    @admin   = users(:admin)
  end

  test "super_admin toggles a checklist key on" do
    sign_in_as @admin
    patch admin_homologation_request_document_checklist_path(@homologation_request),
          params: { document_checklist: { key: "vol", value: "1" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert @homologation_request.reload.checklist_done?("vol")
  end

  test "super_admin toggles a checklist key off" do
    sign_in_as @admin
    patch admin_homologation_request_document_checklist_path(@homologation_request),
          params: { document_checklist: { key: "sol", value: "0" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    refute @homologation_request.reload.checklist_done?("sol")
  end

  test "staff toggles a checklist key on" do
    sign_in_as users(:staff_es)
    patch admin_homologation_request_document_checklist_path(@homologation_request),
          params: { document_checklist: { key: "vol", value: "1" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert @homologation_request.reload.checklist_done?("vol")
  end

  test "students cannot update checklist" do
    sign_in_as users(:student_es)
    patch admin_homologation_request_document_checklist_path(@homologation_request),
          params: { document_checklist: { key: "vol", value: "1" } }
    assert_redirected_to root_path
    refute @homologation_request.reload.checklist_done?("vol")
  end

  test "unauthenticated visitors are redirected to sign in" do
    patch admin_homologation_request_document_checklist_path(@homologation_request),
          params: { document_checklist: { key: "vol", value: "1" } }
    assert_redirected_to new_session_path
  end

  test "unknown key is rejected" do
    sign_in_as @admin
    patch admin_homologation_request_document_checklist_path(@homologation_request),
          params: { document_checklist: { key: "xxx", value: "1" } }

    assert_redirected_to admin_homologation_request_path(@homologation_request)
    assert_not_nil flash[:alert]
  end
end
