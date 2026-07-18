class Admin::HomologationRequests::ConversationsController < ApplicationController
  def create
    request_record = HomologationRequest.kept.includes(:conversation).find(params[:homologation_request_id])
    authorize request_record, :manage_case?

    conversation = request_record.conversation || Conversation.create!(homologation_request: request_record)
    redirect_to conversation_path(conversation)
  end
end
