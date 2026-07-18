class Admin::HomologationRequests::StatusTransitionsController < ApplicationController
  def create
    request_record = HomologationRequest.kept.includes(:user, :conversation).find(params[:homologation_request_id])
    authorize request_record, :manage_case?

    new_status = transition_params[:status].to_s
    reason     = transition_params[:reason].to_s.strip

    notice =
      if new_status == "declined"
        if reason.empty?
          redirect_to admin_homologation_request_path(request_record), alert: t("admin.requests.errors.decline_reason_required") and return
        end
        request_record.decline!(by: Current.user, reason: reason)
        t("flash.request_declined")
      elsif new_status == "awaiting_payment"
        request_record.transition_to!(new_status, changed_by: Current.user)
        t("flash.request_approved_for_payment")
      else
        request_record.transition_to!(new_status, changed_by: Current.user)
        t("flash.status_changed")
      end

    redirect_to admin_homologation_request_path(request_record), notice: notice
  rescue HomologationRequest::InvalidTransition => e
    redirect_to admin_homologation_request_path(request_record), alert: e.message
  end

  private
    def transition_params
      params.expect(status_transition: [ :status, :reason ])
    end
end
