class Admin::HomologationRequests::DocumentChecklistsController < ApplicationController
  def update
    request_record = HomologationRequest.kept.find(params[:homologation_request_id])
    authorize request_record, :manage_case?

    key = checklist_params[:key]
    unless PipelineFlow.checklist_keys.include?(key)
      redirect_to admin_homologation_request_path(request_record), alert: t("errors.unknown_checklist_key") and return
    end

    checklist = (request_record.document_checklist.is_a?(Hash) ? request_record.document_checklist : {}).dup
    checklist[key] = (checklist_params[:value] == "1")
    request_record.update!(document_checklist: checklist)

    redirect_to admin_homologation_request_path(request_record), notice: t("flash.document_checklist_updated")
  end

  private
    def checklist_params
      params.expect(document_checklist: %i[key value])
    end
end
