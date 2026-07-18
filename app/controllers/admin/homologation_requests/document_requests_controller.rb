class Admin::HomologationRequests::DocumentRequestsController < ApplicationController
  def create
    request_record = HomologationRequest.kept.includes(:user, :conversation).find(params[:homologation_request_id])
    authorize request_record, :manage_case?

    reason = document_request_params[:reason].to_s.strip
    if reason.empty?
      redirect_to admin_homologation_request_path(request_record),
                  alert: t("admin.requests.errors.document_request_reason_required") and return
    end

    request_record.request_more_documents!(by: Current.user, reason: reason)
    redirect_to admin_homologation_request_path(request_record),
                notice: t("flash.request_documents_requested")
  rescue HomologationRequest::InvalidTransition => e
    redirect_to admin_homologation_request_path(request_record), alert: e.message
  end

  private
    def document_request_params
      params.expect(document_request: [ :reason ])
    end
end
