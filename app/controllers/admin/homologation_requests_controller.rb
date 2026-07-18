class Admin::HomologationRequestsController < ApplicationController
  def show
    @homologation_request = HomologationRequest.kept
                              .includes(:user, :conversation)
                              .find(params[:id])
    authorize @homologation_request, :manage_case?

    ids = policy_scope(HomologationRequest).kept.order(updated_at: :desc).pluck(:id)
    idx = ids.index(@homologation_request.id) || 0
    @prev_id  = idx.positive? ? ids[idx - 1] : nil
    @next_id  = ids[idx + 1]
    @position = idx + 1
    @total    = ids.size

    @latest_message = @homologation_request.conversation&.messages
                                            &.includes(:user)
                                            &.order(created_at: :desc)
                                            &.first
  end
end
